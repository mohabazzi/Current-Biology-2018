################################################################################
#                                                                              #
#                 Source Code: Bazzi et al. Current Biology                    #
#                                                                              #
################################################################################

################################################################################
#                                                                              #
#  This script contain all necessary code used for geometric morphometric and  # 
#  multivariate statistical analyses.                                          #
#                                                                              #
################################################################################

# R code by Mohamad Bazzi 2018.

# Data can be downloaded from Dryad repository: but also see article.
# We submit custom-made code as separate R scripts. Code will run as long as all
# functions and data are placed within the same working directory and all the packages are installed.

# Required packages and functions -----------------------------------------
library(easypackages)

## Load all necessary packages for analysis:
packages("geomorph", "car", "ggplot2", "gridExtra", "diptest", "moments", "plotrix")

## Functions

# Normality tests for continuous data: Shapiro-Wilks Test
normality.tests <- function(PCA, axis, colour) {
  # First ordination axis
  A <- hist(x = PCA$pc.scores[,axis], plot = FALSE)
  mydensity <- density(PCA$pc.scores[,axis])
  multiplier <- A$counts/A$density
  mydensity$y <- mydensity$y * multiplier[1]
  hist(x = PCA$pc.scores[,axis],col = scales::alpha(colour,.5),border = colour,
            breaks = 10,freq = TRUE,
            xlim = range(PCA$pc.scores[,axis]),ylim = c(0,max(c(A$counts,mydensity$y))),
            xlab = paste('Principal Component ',axis,' (',PCA$pc.summary$importance[2,axis]*100,'%)', sep = ""),
            main = 'Histogram',warn.unused = TRUE,
            plot = TRUE, font.lab = 2)
  # Compute and superimpose density curve on histograms
  lines(x = mydensity,col = 'black',lwd = 2)
  # Quantile-Comparison Plots
  # Normal Probability Plot (QQ-plot) for the first ordination axis
  qqPlot(x = PCA$pc.scores[,axis],col = scales::alpha(colour,.5),
         envelope = .95,col.lines = 'black',
         pch = 19,xlab = '',ylab = '',
         main = 'Normal Q-Q Plot',lwd = 2,
         grid = FALSE)
  # Make x and y label bold
  title(xlab = "Theoretical Quantiles", ylab = 'Sample Quantiles',
        col = 'black',font.lab = 2)
}

# General morphospace descriptive statistics
gms <- function(scores) {
  stats <- c("N","Mean","Median","Shapiro.W","Shapiro.p","Dip.Test.D","Dip.Test.p","Skewness")
  gms.res <- matrix(nrow = ncol(scores),ncol = length(stats))
  for(i in 1:ncol(scores)) {
    n <- nrow(scores)
    mean <- mean(scores[,i])
    median <- median(scores[,i])
    shap.test <- shapiro.test(scores[,i])
    dip.test <- dip.test(scores[,i])
    skew <- skewness(scores[,i])
    gms.res[i,] <- c(n,mean,median,shap.test$statistic,shap.test$p.value,dip.test$statistic,dip.test$p.value,skew)
  }
  colnames(gms.res) <- stats
  rownames(gms.res) <- colnames(scores)
  return(gms.res)
}

#  Compute confidence and prediction intervals
intervals <- function(xvar,alpha = 0.975) {
  mean <- mean(xvar,na.rm = TRUE)
  std <- sd(xvar,na.rm = TRUE)
  n <- length(na.omit(xvar))
  ci.s.x <- sqrt((std^2)/n)
  pi.s.x <- std*sqrt(1 + 1/n)
  t <- qt(alpha,df = n - 1)
  ci.uci <- mean + t*ci.s.x
  ci.lci <- mean - t*ci.s.x
  pi.uci <- mean + t*pi.s.x
  pi.lci <- mean - t*pi.s.x
  res <- as.list(c(round(mean,4),round(std,4),n,round(t,4),round(ci.lci,4),round(ci.uci,4),round(pi.lci,4),round(pi.uci,4)))
  names(res) <- c('mean','st.dev','N','t.stat','Lower.CI','Upper.CI','Lower.PI','Upper.PI')
  return(res)
}

# advanced.procD.lm in geomorph: this performs np-MANOVA and pairwise comparison across all axes and specific axes.
# this function has been deprecated and been replaced with proc.D.lm.
anova.test <- function(scores,bins,axes) {
  nas <- which(is.na(bins))
  if(length(nas) > 0) {
    scores <- scores[-nas,]
    bins <- bins[-nas]
  }
  geomorph.data.all <- geomorph.data.frame(scores = scores, bins = bins)
  npmanova.all <- advanced.procD.lm(f1 = scores~bins,f2 = scores~1,groups = ~bins,data = geomorph.data.all,iter = 999,print.progress = TRUE)
  p.values.all <- npmanova.all$P.means.dist
  p.values.all[lower.tri(p.values.all)] <- p.adjust(p.values.all[lower.tri(p.values.all)],method = "fdr")
  axes.res <- vector(mode = "list",length = length(axes))
  for(i in 1:length(axes)) {
    geomorph.data.ax <- geomorph.data.frame(scores = scores[,axes[i]], bins = bins)
    npmanova.ax <- advanced.procD.lm(f1 = scores~bins,f2 = scores~1,groups = ~bins,data = geomorph.data.ax,iter = 999,print.progress = TRUE)
    p.values.ax <- npmanova.ax$P.means.dist
    p.values.ax[lower.tri(p.values.ax)] <- p.adjust(p.values.ax[lower.tri(p.values.ax)],method = "fdr")
    axes.res[[i]] <- p.values.ax
  }
  return(list(anova.results = npmanova.all,adjusted.p = p.values.all,axes.results = axes.res))
}

# Disparity plot
disp.plot <- function(disp.res,time,col,pch,lty,font.lab = FALSE,add = FALSE) {
  plotCI(time,disp.res$bootstrap.results[,1],li = disp.res$bootstrap.results[,2],
         ui = disp.res$bootstrap.results[,3],ylim = c(-0.040,0.14),
         ylab = "Procrustes Variance", xlab = "",xlim = rev(range(time)),col = col,pch = pch,font.lab = font.lab,add = add)
  lines(time,disp.res$bootstrap.results[,1],lty = lty,col = col)
  # rarefaction
  for(i in 1:length(disp.res$rarefaction.results)) {
    plotCI(time[i],disp.res$rarefaction.results[[i]][1,1],
           li = disp.res$rarefaction.results[[i]][1,2],
           ui = disp.res$rarefaction.results[[i]][1,3],
           pch = pch,add = TRUE, col = "black")
  }
}

# Dental-disparity with permutation
disparity.calc <- function(gpa, data, ages) {
  nas <- which(is.na(data[,ages]))
  if(length(nas) > 0) gm.data <- geomorph.data.frame(coords = gpa$coords[,,rownames(data)[-nas]],ages = data[-nas,ages])
  else gm.data <- geomorph.data.frame(coords = gpa$coords[,,rownames(data)],ages = data[,ages])
  disp <- morphol.disparity(coords~ages,groups = ~ages,iter = 999, data = gm.data)
  return(disp)
}

#  Import and Prepare Metadata --------------------------------------------

## Read shark teeth dataset:
#  Supplementary Data 1
Data <- read.csv(file = "Bazzi et al_Dryad_Data_1.csv")
rownames(Data) <- paste(Data$File.Name, Data$File.Type, sep = "")

## Add $midPoint values to dataset:
midPoint <- Data$FAD + Data$LAD/2
Data$midPoint <- midPoint

## Subset global tooth-dataset by '$order' and create clade-specific data.frames ##
#  Lamniformes:
Data.2 <- Data[Data$Order == "Lamniformes",]
#  Carcharhiniformes:
Data.3 <- Data[Data$Order == "Carcharhiniformes",]

## Regional dataset: Stevns Klint, Denmark ##
#  1) Subset by '$country':
Den.Data <- Data[Data$Country == "Denmark",]
#  2) Call out all rows and columns that are 'Lamniformes' except those that are dated middle Danian:
Den.Data.2 <- Den.Data[Den.Data$Order == "Lamniformes" & Den.Data$Sub != "middle",]
#  3) Do the same for 'Carcharhiniformes':
Den.Data.3 <- Den.Data[Den.Data$Order == "Carcharhiniformes" & Den.Data$Sub != "middle",]

## Preparation of data for validation test (1):
## Global dataset minus regional - Stevns Klint, Denmark - samples:
GR.Data.Lam <- Data.2[Data.2$Country != "Denmark",]
GR.Data.Car <- Data.3[Data.3$Country != "Denmark",]

## Preparation of data for family-level morphospace analysis;
#  more specifically for anacoracids and triakids from the global dataset ##
#  Anacoracidae: all teeth from the Upper Cretaceous (i.e., Maastrichtian)
Anacoracidae <- which(Data.2$Family == "Anacoracidae" & Data.2$Epoch == "Upper")
# Create new data.frame of anacoracids using the integer above (N = 97)
Anacoracidae <- Data.2[Anacoracidae,]
# Do the same for triakids: pull out only those dated as Maastrichtian and Danian/Selandian
Triakidae <- Data.3[Data.3$Family == "Triakidae",]
Triakidae <- Triakidae[which(Triakidae$Age.3 == "Maastrichtian" | Triakidae$Age.3 == "DanSelCombined"),]

## Preparation of data for the second validation test (i.e., heterodonty and its effect on
## temporal patterns in morphospace)

## 1) Call out all lateral and anterior teeth of Lamniformes
##    from the $Standardized.Position column:

# Lateral teeth
Lat.Lamn <- which(Data.2$Standardized.Position == "lateral")
Lat.Lamn <- Data.2[Lat.Lamn,]
# Anterior teeth
Ant.Lamn <- which(Data.2$Standardized.Position == "anterior")
Ant.Lamn <- Data.2[Ant.Lamn,]

# Do the same for Carcharhiniformes:
# Lateral and anterior teeth of Carcharhiniformes ##

# Lateral teeth
Lat.Carch <- which(Data.3$Standardized.Position == "lateral")
Lat.Carch <- Data.3[Lat.Carch,]
# Anterior teeth
Ant.Carch <- which(Data.3$Standardized.Position == "anterior")
Ant.Carch <- Data.3[Ant.Carch,]

# Import and Prepare Landmark Data ----------------------------------------

## Read tps and sliders file: points already sub-sampled following the parameters stipulated in the manuscript
LMs <- readland.tps("Bazzi et al_Dryad_Data_2.tps", specID = "ID")
sliders <- read.csv("Bazzi et al_Dryad_Data_3.csv")

## Now match (%in%) rownames of all landmark configurations from the tps-file
## with rownames in the main dataset (i.e., Data (N = 597))
Landmarks <- LMs[,,rownames(Data)]

## Generalized Procrustes analysis using bending energy for sliding landmarks.
## Define (apex) end-point [-75,]
GPA <- gpagen(A = Landmarks,curves = as.matrix(sliders[-75,]),ProcD = FALSE,Proj = TRUE,print.progress = TRUE)
summary(GPA)
# Optional, but convenient:
consensus <- GPA$consensus
# Plot the results from the GPA
plot(GPA);title(main = "Generalized Procrustes Analysis (GPA)", col.main = "maroon")

# Dimensionality reduction using Principal component analysis (PCA) -------
PCA <- plotTangentSpace(A = GPA$coords,axis1 = 1,axis2 = 2,warpgrids = TRUE,label = TRUE,
                        groups = Data$Order,legend = TRUE)
scores <- PCA$pc.scores
summary <- PCA$pc.summary

## The pc-scores are the 'new' shape variables:
#  Match rownames of both Lamniformes and Carcharhiniformes (datasets) with their respective pc-scores #
#  1) Lamniformes pc-scores:
imp.data <- scores[rownames(Data.2),]
#  2) Carcharhiniformes pc-scores:
imp.data.2 <- scores[rownames(Data.3),]

## Plot shape differences between a reference and target:
#  Axis-specific thin-plate spline deformation grids ##
par(mfrow = c(1,2))
plotRefToTarget(consensus,PCA$pc.shapes$PC1min,method = "TPS")
plotRefToTarget(consensus,PCA$pc.shapes$PC1max,method = "TPS")
plotRefToTarget(consensus,PCA$pc.shapes$PC2min,method = "TPS")
plotRefToTarget(consensus,PCA$pc.shapes$PC2max,method = "TPS")

# Plot consensus 'mean morphology' or reference shape)
plotRefToTarget(GPA$consensus,GPA$consensus);title(main = "Mean Morphology")

# Statistical Data Exploration --------------------------------------------

# Normality test of data using Shapiro-Wilk test
# Specifying Complex Plot Arrangements
layout(matrix(c(1:4),ncol = 2,byrow = TRUE))
normality.tests(PCA, 1, '#E41A1C')
normality.tests(PCA, 2, '#377EB8')
normality.tests(PCA, 3, '#E41A1C')
normality.tests(PCA, 4, '#377EB8')

## Identify components to retain using the Broken-stick criterion:
#  Supplementary Figure 1
par(mfrow = c(1,2))

barplot(PCA$pc.summary$importance[2,1:5], main = "Barplot",
        ylab = "Proportion of Variance Explained",xlab = "Principal Components",
        col = "black",font.lab = 2,border = "lightgrey")

plot(PCA$pc.summary$importance[2,1:5], col = "black",
     main = "Broken Stick criterion", ylab = "Proportion of Variance Explained",
     xlab = "Principal Components", type = "b",pch = 19, font.lab = 2, lwd = 2)

# Analyses & Figures ------------------------------------------------------

## Compute general morphospace with density curves using ggplot2 & ggthemes ##
# PC1 vs. PC2: Text Figure 1
source(file = "Morphospace_PC1-PC2.R")
# PC3 vs. PC4: Supplementary Figure 15
source(file = "Morphospace_PC3-PC4.R")

## Statistical output related to the general morphospace ## 
#  Lamniformes: first 4 axes (Supplementary Table 21)
gms1 <- gms(imp.data[,1:4])
# Carcharhiniformes: first 4 axes (Supplementary Table 22)
gms2 <- gms(imp.data.2[,1:4])

## Main time-series 'morphospace' analysis: source code to print results

# Global four-binning scheme: Supplementary Figure 2 and 18
source(file = 'TemporalMorph_PC1-PC2_4Bins.R')
source(file = 'TemporalMorph_PC3-PC4_4Bins.R')

# Global three-binning scheme: Text Figure 2 and Supplementary Figure 16
source(file = 'TemporalMorph_PC1-PC2_3Bins.R')
source(file = 'TemporalMorph_PC3-PC4_3Bins.R')

# Regional two-binning scheme: Text Figure 3 and Supplementary Figure 17
source(file = 'TemporalMorph_PC1-PC2_2Bins.R')
source(file = 'TemporalMorph_PC3-PC4_2Bins.R')

## Validation test 1: using the global three-binned time division scheme:
## Subtracting sub-samples from Stevns Klint, Denmark from the global dataset ##

# Index 'pc.scores' first so that both dataset(s) match in length
new.scores.lamn <- scores[rownames(GR.Data.Lam),]
new.scores.carc <- scores[rownames(GR.Data.Car),]

# Supplementary Figure 6
source(file = 'ValidationTest_PC1-PC2_3Bins.R')

# Now to compute family-level morphospace time-series 
# for anacoracids and triakids: 
# 1) create new 'pc-scores' vector(s) matching with meta-data
#    in the 'Anacoracidae' spreed-sheet (N = 97) and the same for 'Triakidae' (N = 71)
ana.scores <- imp.data[rownames(Anacoracidae),]
tri.scores <- imp.data.2[rownames(Triakidae),]

# Text Figure 6
source(file = "Triakidae-Anacoracids_PC1-PC2.R")

## Validation test 2: Explore morphospace occupation of relative
#  tooth positions of respective clades
#  Remove empty levels using complete.cases () function ##
Lamn.Tooth.Position <- Data.2[complete.cases(Data.2$Standardized.Position), ]
Lamn.Tooth.Position.Vector <- imp.data[rownames(Lamn.Tooth.Position),]

Carch.Tooth.Position <- Data.3[complete.cases(Data.3$Standardized.Position), ]
Carch.Tooth.Position.Vector <- imp.data.2[rownames(Carch.Tooth.Position),]

# Supplementary Figure 9 - Lamniformes
source(file = "ToothPositions_Lamniformes.R")
# Sample size of standardized tooth positions in Lamniformes:
tapply(X = Data.2$Standardized.Position,INDEX = Data.2$Standardized.Position,length)
# np-MANOVA result for standardized tooth positions in Lamniformes
# ... but first run function (np-MANOVA) below:
sta.lamn.posi <- anova.test(scores = Lamn.Tooth.Position.Vector,
                            bins = Lamn.Tooth.Position$Standardized.Position,
                            axes = 1:4)

# Supplementary Figure 10 - Carcharhiniformes
source(file = "ToothPositions_Carcharhiniformes.R")
# Sample size of standardized tooth positions in Lamniformes 
tapply(X = Data.3$Standardized.Position,INDEX = Data.3$Standardized.Position,length)
# np-MANOVA result for standardized tooth positions in Lamniformes 
sta.carch.posi <- anova.test(scores = Carch.Tooth.Position.Vector,
                             bins = Carch.Tooth.Position$Standardized.Position,
                             axes = 1:4)

## Validation test 3: Heterodonty (time-series) - anterior vs.lateroposterior teeth
#  1) create new 'pc-scores' vector(s) matching with meta-data
#     in the 'Lat.Lamn' spreed-sheet (N = 235) and the same for 'Lat.Carch' (N = 91)
lamn.lateral.scores <- imp.data[rownames(Lat.Lamn),]
carch.lateral.scores <- imp.data.2[rownames(Lat.Carch),]
#  2) do the same for anterior tooth positions:
lamn.anterior.scores <- imp.data[rownames(Ant.Lamn),]
carch.anterior.scores <- imp.data.2[rownames(Ant.Carch),]

# Supplementary Figure 11
source(file = "HeterdontyTest_AnteriorTeeth_PC1-PC2.R")
# Supplementary Figure 12
source(file = "HeterdontyTest_LateralTeeth_PC1-PC2.R")

# Global Lamniforms: 4-bins
lam.anova.4bin <- anova.test(scores = imp.data,bins = Data.2$Age,axes = 1:4)
# Global Lamniforms: 3-bins
lam.anova.3bin <- anova.test(scores = imp.data,bins = Data.2$Age.3,axes = 1:4)
# Global Carcharhiniforms: 4-bins
car.anova.4bin <- anova.test(scores = imp.data.2,bins = Data.3$Age,axes = 1:4)
# Global Carcharhiniforms: 3-bins
car.anova.3bin <- anova.test(scores = imp.data.2,bins = Data.3$Age.3,axes = 1:4)

# Regional Lamniforms: 2-bins
lam.anova.2bin <- anova.test(scores = imp.data[rownames(Den.Data.2),],bins = Den.Data.2$Sub,axes = 1:4)
# Regional Carcharhiniforms: 2-bins
car.anova.2bin <- anova.test(scores = imp.data.2[rownames(Den.Data.3),],bins = Den.Data.3$Sub,axes = 1:4)

## Two-sample Kolmogorov-Smirnov test ##
## Compares observed and expected cumulative frequencies ##

# Lamniformes: 4-bins
ks.test(x = imp.data[Data.2$Age == "Maastrichtian",1],y = imp.data[Data.2$Age == "Danian",1])
# Lamniformes: 3-bins
ks.test(x = imp.data[Data.2$Age.3 == "Maastrichtian",1],y = imp.data[Data.2$Age.3 == "DanSelCombined",1])

# Carcharhinifoms: 4-bins
ks.test(x = imp.data.2[Data.3$Age == "Maastrichtian",1],y = imp.data.2[Data.3$Age == "Danian",1])
# Carcharhinifoms: 3-bins and adjusted p-value
ks.test.carh.three.bin <- ks.test(x = imp.data.2[Data.3$Age.3 == "Maastrichtian",1],y = imp.data.2[Data.3$Age.3 == "DanSelCombined",1])
# Adjust p-value
p.adj  <- p.adjust(ks.test.carh.three.bin$p.value, method = "fdr")

## Skewness of sample distributions along ordinated (scaled) axes ##
## Lamniformes: 3 and 4 bin-analysis
skewness(imp.data[Data.2$Age.3 == "Maastrichtian",4],na.rm = TRUE)
skewness(imp.data[Data.2$Age.3 == "DanSelCombined",4],na.rm = TRUE)
skewness(imp.data[Data.2$Age == "Danian",4],na.rm = TRUE)
skewness(imp.data[Data.2$Age == "Selandian",4],na.rm = TRUE)
skewness(imp.data[Data.2$Age.3 == "Thanetian",4],na.rm = TRUE)
## Carcharhiniformes: 3 and 4 bin-analysis
skewness(imp.data.2[Data.3$Age.3 == 'Maastrichtian',4],na.rm = TRUE)
skewness(imp.data.2[Data.3$Age.3 == 'DanSelCombined',4],na.rm = TRUE)
skewness(imp.data.2[Data.3$Age == 'Danian',4],na.rm = TRUE)
skewness(imp.data.2[Data.3$Age == 'Selandian',4],na.rm = TRUE)
skewness(imp.data.2[Data.3$Age.3 == 'Thanetian',4],na.rm = TRUE)

## Regional 2 bin-analysis: Lamniformes and Carcharhiniformes
## 1) subset pc-scores for regional dataset
reg.lamn.scores <- imp.data[rownames(Den.Data.2),] # Lamniformes
reg.carch.scores <- imp.data.2[rownames(Den.Data.3),] # Carcharhiniformes
## 2) compute skewness:
# Lamniformes
skewness(reg.lamn.scores[Den.Data.2$Sub == "early",1],na.rm = TRUE)
skewness(reg.lamn.scores[Den.Data.2$Sub == "late",1],na.rm = TRUE)
# Carcharhiniformes
skewness(reg.carch.scores[Den.Data.3$Sub == "early",1],na.rm = TRUE)
skewness(reg.carch.scores[Den.Data.3$Sub == "late",1],na.rm = TRUE)

# Morphological disparity and rarefaction analysis ------------------------

# Source function called error.plot, WARNING high replicate values are computationally intensive
source(file = 'Morphological Disparity with Bootstrap.R')

## Save results from the morphological disparity analysis - as a PDF-file.
pdf("Disparity-through-time.pdf", width = 10, height = 8)

## Lamniformes
## Global-level analysis: Four and Three-bins
## Set graphical parameter (alt.2)
par(mfrow = c(2,1),oma = c(0,0,0,5))
par(mfrow = c(2,1), mar = c(4,4,1,1), oma = c(2,2,2,2)) # This one for publication
par(mfrow = c(2,1))

# Four-bins:
## system.time() function
lamn.disp.4bin <- error.plot(gpa.coords = GPA$coords[,,rownames(Data.2)],
                             blank = FALSE,groups = Data.2$Age,order = c(2,1,3,4),
                             replicates = 999,rarefy.par = list(min.N = 23,reps = 999))
# Three-bins:
lamn.disp.3bin <- error.plot(gpa.coords = GPA$coords[,,rownames(Data.2)],
                             blank = FALSE,groups = Data.2$Age.3,order = c(2,1,3),
                             replicates = 999,rarefy.par = list(min.N = 50,reps = 999))
# Regional-level analysis:
lamn.reg.disp <- error.plot(gpa.coords = GPA$coords[,,rownames(Den.Data.2)],
                            blank = FALSE,groups = Den.Data.2$Sub,order = 2:1,
                            replicates = 999,rarefy.par = list(min.N = 6,reps = 999))
# Plot results:
disp.plot(lamn.disp.4bin,time = c(69.05,63.8,60.4,57.6),col = "#E41A1C",pch = 19,lty = 1,font.lab = 2)
disp.plot(lamn.disp.3bin,time = c(69.05,62.1,57.6),col = "#E41A1C",pch = 19,lty = 2,font.lab = NULL,add = TRUE)
disp.plot(lamn.reg.disp,time = c(67.525,64.9),col = "#E41A1C",pch = 17,lty = 1,font.lab = NULL,add = TRUE)

# Add legend to lamniform plot
# Color vector:
disp.col <- c("#E41A1C","#E41A1C","black","#E41A1C","black")
legend("topright",col = disp.col,
       legend = c("Global (4-bin)","Global (3-bin)","Rarefied","Regional (2-bin)","Regional Rarefied"),
       pch = c(19,19,19,17,17),lty = c(1,2,0,1,0),bty = "n",pt.bg = disp.col,
       cex = .75,title = expression(bold("Lamniformes")),border = TRUE,
       box.lty = 1,box.lwd = 1, box.col = "black",xjust=0, yjust = 0,
       text.col = 'black',title.col = 'black',
       lwd = 1,text.font = 1); title(main = "Disparity through time",outer = T)

# Add vertical line at K-Pg event:
abline(v = 66, col = 'black')

# Lamniformes disparity, permutation tests: Four-bins
disparity.calc(gpa = GPA, data = Data.2, ages = "Age")
# Three-bins
disparity.calc(gpa = GPA, data = Data.2, ages = "Age.3")
# Regional
disparity.calc(gpa = GPA, data = Den.Data.2, ages = "Sub")

## Carcharhiniformes
# Global-level analysis: Four-bin
carc.disp.4bin <- error.plot(gpa.coords = GPA$coords[,,rownames(Data.3)],
                        blank = FALSE,groups = Data.3$Age,order = c(2,1,3,4),
                        replicates = 999,rarefy.par = list(min.N = 2,reps = 999))
# Three-bins:
car.disp.3bin <- error.plot(gpa.coords = GPA$coords[,,rownames(Data.3)],
                             blank = FALSE,groups = Data.3$Age.3,order = c(2,1,3),
                             replicates = 999,rarefy.par = list(min.N = 40,reps = 999))
# Regional-level analysis:
carc.reg.disp <- error.plot(gpa.coords = GPA$coords[,,rownames(Den.Data.3)],
                            blank = FALSE,groups = Den.Data.3$Sub,order = 2:1,
                            replicates = 999,rarefy.par = list(min.N = 14,reps = 999))

# Plot disparity results:
disp.plot(carc.disp.4bin,time = c(69.05,63.8,60.4,57.6),col = "#377EB8",pch = 19,lty = 1,font.lab = 2)
disp.plot(car.disp.3bin,time = c(69.05,62.1,57.6),col = "#377EB8",pch = 19,lty = 2,font.lab = NULL,add = TRUE)
disp.plot(carc.reg.disp,time = c(67.525,64.9),col = "#377EB8",pch = 17,lty = 1,font.lab = NULL,add = TRUE)

# Add legend to Carcharhiniformes plot:
legend("topright",
       col = c("#377EB8","#377EB8","black","#377EB8","black"),
       legend = c("Global (4-bin)","Global (3-bin)","Rarefied","Regional (2-bin)","Regional Rarefied"),
       pch = c(19,19,19,17,17),lty = c(1,2,0,1,0),bty = "n",
       cex = .75,title = expression(bold("Carcharhiniformes")),border = TRUE,
       box.lty = 1,box.lwd = 1, box.col = "black",xjust = 0, yjust = 0,
       text.col = "black",title.col = "black",lwd = 1,text.font = 1)

# Add vertical line at K-Pg event:
abline(v = 66, col = "black")

dev.off()

# Carcharhiniformes disparity, permutation tests: 4-bins
disparity.calc(gpa = GPA, data = Data.3, ages = "Age")
# Carcharhiniformes disparity, permutation tests: 3-bins
disparity.calc(gpa = GPA, data = Data.3, ages = "Age.3")
# Carcharhiniformes disparity, permutation tests - Regional
disparity.calc(gpa = GPA, data = Den.Data.3, ages = "Sub")


### World Map in Figure 1 ###
world <- ggplot() +
  borders("world", colour = "gray85", fill = "gray80",alpha = .5) +
  theme_map() +
  theme(axis.title = element_text(face="bold"))+
  xlab('Longitude') +
  ylab('Latitude')

###############################################
######## The End