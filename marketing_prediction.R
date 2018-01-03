rm(list=ls()) #### Running to free up space

######## libraries #######################
library(caret) 
library(dplyr)
library(Hmisc)
library(randomForest)
library(pROC)
library(ROSE)
###########################################
train_data_loc<-"/data/analytics/jay/Spark/marketing_training.csv"
test_data_loc<-"/data/analytics/jay/Spark/marketing_test.csv"
final_output_loc<-"/data/analytics/jay/Spark/marketing_test_predicted.csv"
set.seed(100)
# Split the data into training & Validation set

data<-read.csv(train_data_loc)
inTrain<-createDataPartition(y=data$responded , p=0.7 , list=FALSE)
trainingX<-data[inTrain,]
validation<-data[-inTrain,]
headers1<-names(trainingX) 
table(trainingX$responded)
################# Imbalance in classes: Over sampling the minority class and under sampling the majority class ##########
training<-ovun.sample(responded ~ ., data = trainingX, method = "both", p=0.7,N=3000, na.action=na.keep , seed=100)$data
###########################################################################################################

headers<-headers1[headers1!="responded" & headers1!="marital" & headers1!="default" & headers1!="schooling"]

################# Missing values replacement : replaceing custAge using pmm(predictive mean mapping)
fmla <- as.formula(paste(" ~ ", paste("I(",headers,")", collapse=" +")))
impute_arg_train<-aregImpute(fmla , data=training , n.impute=5, nk=3)
imputed_custAge<-round(apply(impute_arg_train$imputed$custAge , 1,mean , drop=F))
imputed_custAge<-data.frame("custAge1"=imputed_custAge)
training1<-merge(training , imputed_custAge , all.x=T , by=0, sort = FALSE)
training1$custAge<- ifelse(is.na(training1$custAge) , training1$custAge1 , training1$custAge )
training_after_imputation<-subset(training1 , select=-c(custAge1,Row.names))
################# Creating Random forest model ##################################
modRF = randomForest(responded~., training_after_imputation, ntree=200 , do.trace=TRUE , seed=100)
################# Checking accuracy on validation set
impute_arg_valid<-aregImpute(fmla , data=validation , n.impute=5, nk=3)
imputed_custAge<-round(apply(impute_arg_valid$imputed$custAge , 1,mean , drop=F))
imputed_custAge<-data.frame("custAge1"=imputed_custAge)
validation1<-merge(validation , imputed_custAge , all.x=T , by=0, sort = FALSE)
validation1$custAge<- ifelse(is.na(validation1$custAge) , validation1$custAge1 , validation1$custAge )
validation_after_imputation<-subset(validation1 , select=-c(custAge1,Row.names))
pred=predict(modRF,validation_after_imputation)

################# Metrics for performance evaluation: AUC,TPR & FPR ###################
misclass=function(values,prediction){ sum(ifelse(values!=prediction,1,0))/length(values) } 
misclass(validation_after_imputation$responded , pred )
response<-ifelse(validation_after_imputation$responded=="yes",1,0)
prediction<-ifelse(pred=="yes",1,0) 
auc1=auc(response,prediction)
cM<-confusionMatrix(prediction,response)
fpr<-cM$byClass["Sensitivity"]
tpr<-cM$byClass["Specificity"]
print(paste("AUC",auc1[1],sep=" "))
print (paste("TPR",tpr ,sep=" "))
print(paste("FPR",fpr ,sep=" "))
################ Running on the test data ################################################
testing<-read.csv(test_data_loc)
colnames(testing)[1] <- "id"
headers<-headers1[headers1!="responded" & headers1!="marital" & headers1!="default" & headers1!="schooling" & headers1!="month" & headers1 !="id"]
fmla <- as.formula(paste(" ~ ", paste("I(",headers,")", collapse=" +")))

impute_arg_test<-aregImpute(fmla , data=testing , n.impute=5, nk=3)
imputed_custAge<-round(apply(impute_arg_test$imputed$custAge , 1,mean , drop=F))
imputed_custAge<-data.frame("custAge1"=imputed_custAge)
testing1<-merge(testing , imputed_custAge , all.x=T , by=0, sort = FALSE)
testing1$custAge<- ifelse(is.na(testing1$custAge) , testing1$custAge1 , testing1$custAge )
testing_after_imputation<-subset(testing1 , select=-c(custAge1,Row.names,id))
for(var in c('default' , 'profession' ,'schooling' , 'marital', 'housing')){
levels(testing_after_imputation[,var]) <- levels(training_after_imputation[,var])
}
pred=predict(modRF,testing_after_imputation) 
results<-cbind(id=testing$id,data.frame(responded=pred)) 
write.csv(results, file = final_output_loc)
###########################################################################################
#Other Tasks Using GLM Model
modGLM = train(responded~., training_after_imputation,method='glm') 
table(validation_after_imputation$responded)
pred1<-predict(modGLM,validation_after_imputation)
misclass(validation_after_imputation$responded , pred1 )
confusionMatrix(validation_after_imputation$responded , pred1)
######## General analysis ######################
nrow(training[is.na(training$custAge),])
qplot(training$campaign, training$custAge, color=training$responded , xlab="Campaign (# of lines)" , ylab="Customer age" , geom="jitter")
remove_999 <- training %>%filter(pdays!=999 )
qplot(remove_999$poutcome, remove_999$custAge, color=remove_999$responded )
qplot(training$previous, training$custAge, color=training$responded )
student_under30 <- training %>%filter(custAge<=30,profession=="student" )
retired_above60 <- training %>%filter(custAge>=60,profession=="retired" )
nrow(student_under30[student_under30$responded=='no',])/nrow(student_under30)
retired_above60 <- training %>%filter(custAge>=60,profession=="retired" )
summary(retired_above60)
default_no<-training %>%filter(default=="no" )
default_unknown<-training %>%filter(default=="unknown" )
loan_taken<-training %>%filter(loan=="no" )
nrow(loan_taken[loan_taken$responded=='yes',])/nrow(loan_taken)
nrow(training)
summary(trainingX)
