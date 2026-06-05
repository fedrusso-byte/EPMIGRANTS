#converter

fname <- "qt_2022coded"
cbook.fname <- "codebook_it.xlsx"

origdat <- xlsx::read.xlsx( file.path("data", sprintf("%s.xlsx",fname)), sheetIndex = 1)
codebook <- xlsx::read.xlsx( file.path("data", cbook.fname), sheetIndex = 1)
origdat$majortopic <- floor(origdat$cap_ita/100) 
origdat$minor.topic <- origdat$cap_ita
idx <- which(is.na(origdat$testo))
if(length(idx)>0)
  origdat <- origdat[-idx,]
write.csv(origdat,file=file.path("data", sprintf("%s.csv",fname)), row.names = FALSE)



fname.in <- "training_set_embeddings"
fname.out <- "training_set_tweets"
dat <- read.csv( file.path("data", sprintf("%s.csv",fname.in)))
dat$id <- 1:nrow(dat)
dim(dat)
idx <- which(is.na(dat$majortopic))
if(length(idx)>0){
  dat <- dat[-idx,]
}
dim(dat)
write.csv(dat, file.path("data", sprintf("%s.csv",fname.out)), row.names = FALSE)

