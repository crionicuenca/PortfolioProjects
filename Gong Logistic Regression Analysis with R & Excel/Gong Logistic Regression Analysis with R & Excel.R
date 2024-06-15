# LOAD DATA AND PACKAGES
# install.packages(c("caret","devtools","ggeffects")
# devtools::install_github("cardiomoon/ggiraphExtra")
library(caret)
library(dplyr)
library(MASS)
library(ggeffects)

example1 <- read.csv("example1.csv")
example2 <- read.csv("example2.csv")
example3 <- read.csv("example3.csv")

# combine all data sets into one list
data <- list(example1, example2, example3)
# list of all data set names and plot titles
data_names <- data.frame(
              "var_names"=c("example1","example2","example3"),
              "var_names2"=c("Example 1","Example 2","Example 3"),
              "plot_titles"=c("Example 1 Plot","Example 2 Plot","Example 3 Plot"))

# model summaries
summary1 <- list()
summary2 <- data.frame()

# PERFORM STEPWISE LOG REG ON EACH DATASET VIA FOR LOOP
for (i in 1:length(data)) {
  # clean data and remove unnecessary columns
  dataset = data[[i]]
  dataset = subset(data[[i]], select=-c(id, won, duration, collab_tool))
#  dataset = subset(data[[i]], select=-c(id, won, duration, goto, webex, teams, zoom))
  dataset = na.omit(dataset)

  # perform stepwise logistic regression
  null_model <- glm(lost ~ 1, data=dataset, family=binomial)
  full_model <- glm(lost ~ ., data=dataset, family=binomial)
  step_model <- full_model %>% stepAIC(direction="both", trace=FALSE)
  
  # step model prediction accuracy
  step_prob <- step_model %>% predict(dataset, type="response")
  step_pred <- ifelse(step_prob > 0.5, 1, 0)
  step_mean <- mean(step_pred == dataset$lost)
  step_pchisq <- pchisq((deviance(null_model) - deviance(step_model)),
                        length(coef(step_model))-1, lower.tail=FALSE)
  
  # save model summary
  summary1[[i]] = summary(step_model)
  summary2[i,1] = data_names[i,2]
  summary2[i,2] = step_mean
  summary2[i,3] = step_pchisq
  
  # plot predictors with marginal effect
  legend <- c("1- Actual Data"="black", "3- LogReg Line"="red", "2- Predicted Prob"="skyblue", "4- Prob = 0.5"="red")
  step_df <- data.frame(dataset, prob=step_prob)
  step_coeffs <- c(rownames(coef(summary(step_model, complete=TRUE))))[-1]
  # plot
  for (j in 1:length(step_coeffs)) {
    # make logistic regression line per coeff via ggpredict
    pred_coeff <- ggpredict(step_model, paste(step_coeffs[j], "[all]", collapse=""))
    # return index of step model coeffs in step_df
    coeff_index <- match(step_coeffs[j], colnames(step_df))
    # approx x value when y = 0.5
    half_prob_y1 <- which(abs(pred_coeff$predicted - 0.5) == min(abs(pred_coeff$predicted - 0.5)))
    half_prob_y2 <- pred_coeff$predicted[half_prob_y1 + 1]
    half_prob_x2 <- pred_coeff$x[half_prob_y1 + 1]
    half_prob_x1 <- pred_coeff$x[half_prob_y1]
    half_prob_y1 <- pred_coeff$predicted[half_prob_y1]
    half_prob <- (0.5-half_prob_y1)*((half_prob_x2-half_prob_x1)/(half_prob_y2-half_prob_y1)) + half_prob_x1
    half_prob <- round(half_prob, 2)
    
    # plot
    step_coeff_plot <- ggplot(data=step_df, aes(x=step_df[[coeff_index]], y=lost))+
      geom_point(data=step_df, aes(x=step_df[[coeff_index]], y=prob, color="2- Predicted Prob"), shape=1)+
      geom_point(data=step_df, aes(x=step_df[[coeff_index]], y=lost, color="1- Actual Data"), shape=1)+
      geom_line(data=pred_coeff, aes(x=x,y=predicted, color="3- LogReg Line"))+
      geom_hline(aes(yintercept=0.5, color="4- Prob = 0.5"), linetype="dashed")+
#      geom_point(aes(x=half_prob, y=0.5), color="red")+
#      annotate("text",label=paste("          ", half_prob, collapse=""), x=half_prob, y=0.485, size=3, color="red")+
      labs(x=paste(step_coeffs[j], "# of occurences", collapse=""), y="lost (0=no, 1=yes)")+
      scale_color_manual(name="", values=legend, guide=guide_legend(
        override.aes=list(linetype=c("blank","blank","solid","dashed"), shape=c(1,1,NA,NA))))+
      ggtitle(label=data_names[i,3],
              subtitle=paste("Probabiliy of lost by", step_coeffs[j], collapse=""))
    plot(step_coeff_plot)

    # download each plot
    # save_path <- file.path ("C:","Users","crioni.cuenca","Downloads",
    #                         paste("lost_", data_names[i,1], "_", step_coeffs[j], ".png", sep=""))
    # png(save_path)
    # plot(step_coeff_plot)
    # dev.off()
  }
}

# print summaries
summary2 <- summary2 %>% rename(" "=V1, "Accuracy of Step Model"=V2, "P-value from Chi-Square"=V3)
summary1
summary2