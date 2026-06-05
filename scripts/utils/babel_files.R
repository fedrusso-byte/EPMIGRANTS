

## create training and test set for Babel

library(dplyr)

rm(list=ls())

pre_coded <- read.csv("train-ung.csv", header=TRUE, row.names=NULL, sep="\t")

pre_coded <- rename(pre_coded, id = idCoding, major_topic = majorV3Code)

pre_coded <- select(pre_coded, !majorV3)

str(pre_coded)

View(pre_coded)

write.csv(pre_coded,file="pre_coded_epq.csv", row.names = FALSE)

# 

non_coded <- read.csv("test-ung.csv", header=TRUE, row.names=NULL, sep="\t")

non_coded <- rename(non_coded, id = idCoding)

non_coded <- select(non_coded, id, text)

str(non_coded)

View(non_coded)

write.csv(non_coded,file="non_coded_epq.csv", row.names = FALSE)


## Bind training set

library(tidyverse)

training_1 <- read.csv("data/training_set_1_gpt4_coded.csv", header=TRUE, row.names=NULL)
training_2 <- read.csv("data/training_set_2_V3_coded.csv", header=TRUE, row.names=NULL)
training_3 <- read.csv("data/training_set_3_V3_coded.csv", header=TRUE, row.names=NULL)
training_4 <- read.csv("data/training_set_4_V3_coded.csv", header=TRUE, row.names=NULL)
training_5 <- read.csv("data/training_set_5_V3_coded.csv", header=TRUE, row.names=NULL)

training <- bind_rows(training_1, training_2, training_3, training_4, training_5)

write.csv(training,file="./data/training.csv", row.names = FALSE)



