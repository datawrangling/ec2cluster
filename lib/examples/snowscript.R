#! /usr/bin/env Rscript
#
# R Snow example, from http://www.stat.uiowa.edu/~luke/classes/295-hpc/
## Boot up lam with lamhosts10 and go into xmpi, or
## boot up bvm with xpvm and 10 hosts

library(snow)
cl <- makeCluster(10) 

##
## Simple Examples
##

system.time(clusterCall(cl, Sys.sleep, 10))

x <- 1:100/101
system.time(parLapply(cl, x, qtukey, 2, df=2))


##
## Matrix Multiply
##

## first implementation

parMM <- function(cl, A, B, Pmax = length(cl)) {
    r <- nrow(A)
    c <- ncol(B)
    pr <- min(Pmax, max(1, floor(sqrt(Pmax * r / c))))
    pc <- floor(Pmax / pr)
    A_rows <- rep(splitRows(A, pr), pc)
    B_cols <- rep(splitCols(B, pc), each = pr)
    args <- mapply(list, A_rows, B_cols, SIMPLIFY = FALSE)
    Cblocks <- clusterApply(cl, args,
                            function(arg) arg[[1]] %*% arg[[2]])
    C_cols <- lapply(splitList(Cblocks, pc),
                     function(x) docall(rbind, x))
    docall(cbind, C_cols)
}

n <- 1000
A <- matrix(rnorm(n * n), n)

system.time(parMM(cl, A, A))

## second implementation

parMMhelper <- function(arg) arg[[1]] %*% arg[[2]]

parMM <- function(cl, A, B, Pmax = length(cl)) {
    r <- nrow(A)
    c <- ncol(B)
    pr <- min(Pmax, max(1, floor(sqrt(Pmax * r / c))))
    pc <- floor(Pmax / pr)
    A_rows <- rep(splitRows(A, pr), pc)
    B_cols <- rep(splitCols(B, pc), each = pr)
    args <- mapply(list, A_rows, B_cols, SIMPLIFY = FALSE)
    Cblocks <- clusterApply(cl, args, parMMhelper)
    C_cols <- lapply(splitList(Cblocks, pc),
                     function(x) docall(rbind, x))
    docall(cbind, C_cols)
}

system.time(parMM(cl, A, A))

## third implementation

parMM <- function(cl, A, B, Pmax = length(cl)) {
    r <- nrow(A)
    c <- ncol(B)
    pr <- min(Pmax, max(1, floor(sqrt(Pmax * r / c))))
    pc <- floor(Pmax / pr)
    A_rows <- rep(splitRows(A, pr), pc)
    B_cols <- rep(splitCols(B, pc), each = pr)
    Cblocks <- clusterMap(cl, `%*%`, A_rows, B_cols)
    C_cols <- lapply(splitList(Cblocks, pc),
                     function(x) docall(rbind, x))
    docall(cbind, C_cols)
}

system.time(parMM(cl, A, A))


##
## Bootstrap
##

library(boot)
#  In this example we show the use of boot in a prediction from 
#  regression based on the nuclear data.  This example is taken 
#  from Example 6.8 of Davison and Hinkley (1997).  Notice also 
#  that two extra arguments to statistic are passed through boot.
data(nuclear)
nuke <- nuclear[,c(1,2,5,7,8,10,11)]
nuke.lm <- glm(log(cost)~date+log(cap)+ne+ ct+log(cum.n)+pt, data=nuke)
nuke.diag <- glm.diag(nuke.lm)
nuke.res <- nuke.diag$res*nuke.diag$sd
nuke.res <- nuke.res-mean(nuke.res)

#  We set up a new dataframe with the data, the standardized 
#  residuals and the fitted values for use in the bootstrap.
nuke.data <- data.frame(nuke,resid=nuke.res,fit=fitted(nuke.lm))

#  Now we want a prediction of plant number 32 but at date 73.00
new.data <- data.frame(cost=1, date=73.00, cap=886, ne=0,
                       ct=0, cum.n=11, pt=1)
new.fit <- predict(nuke.lm, new.data)

nuke.fun <- function(dat, inds, i.pred, fit.pred, x.pred) {
     assign(".inds", inds, envir=.GlobalEnv)
     lm.b <- glm(fit+resid[.inds] ~date+log(cap)+ne+ct+
                 log(cum.n)+pt, data=dat)
     pred.b <- predict(lm.b,x.pred)
     remove(".inds", envir=.GlobalEnv)
     c(coef(lm.b), pred.b-(fit.pred+dat$resid[i.pred]))
}


## sequential version

R <- 1000
system.time(nuke.boot <-
            boot(nuke.data, nuke.fun, R=R, m=1,
                 fit.pred=new.fit, x.pred=new.data))

## parallel version

clusterEvalQ(cl,library(boot))

clusterSetupRNG(cl)
system.time(cl.nuke.boot <-
            clusterCall(cl,boot,nuke.data, nuke.fun, R=R/length(cl), m=1,
                        fit.pred=new.fit, x.pred=new.data))

## merging the results

fixboot <- function(bootlist) {
    boot <- bootlist[[1]]
    boot$t <- do.call(rbind,lapply(bootlist, function(x) x$t))
    boot$R <- sum(sapply(bootlist, function(x) x$R))
    if (! is.null(boot$pred.i))
        boot$pred.i <- do.call(rbind,lapply(bootlist,
                                            function(x) x$pred.i))
    boot
}

cl.nuke.boot.fixed <- fixboot(cl.nuke.boot)

##  The bootstrap prediction error would then be found by
mean(nuke.boot$t[,8]^2)
mean(cl.nuke.boot.fixed$t[,8]^2)

##  Basic bootstrap prediction limits would be
new.fit-sort(nuke.boot$t[,8])[c(975,25)]
new.fit-sort(cl.nuke.boot.fixed$t[,8])[c(975,25)]
