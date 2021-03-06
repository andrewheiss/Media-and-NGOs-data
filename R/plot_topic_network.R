# Title:          plot_topic_network.R
# Description:    Plot a dendrogram of the topic model
# Author:         Andrew Heiss
# Last updated:   2014-03-25
# R version:      ≥3.0

# Huge thanks to Rolf Fredheim for creating the arcplot + dendrogram + topic proportions idea!
# http://quantifyingmemory.blogspot.com/2013/11/visualising-structure-in-topic-models.html

# Inspiration and help for this:
#   * http://gastonsanchez.wordpress.com/2013/02/02/star-wars-arc-diagram/
#   * http://tedunderwood.com/2012/11/11/visualizing-topic-models/

# Useful dendrogram resources:
#   * http://rpubs.com/gaston/dendrograms
#   * http://wheatoncollege.edu/lexomics/files/2012/08/How-to-Read-a-Dendrogram-Web-Ready.pdf


# Load libraries
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(plyr))
suppressPackageStartupMessages(library(grid))
suppressPackageStartupMessages(library(reshape2))
suppressPackageStartupMessages(library(ggdendro))

# Load topic model
load("../Output/topic_model.RData")


#-----------------------------------------
# Create correlation and dendrogram data
#-----------------------------------------
# Create data frames
df <- topic.docs.norm
df$X19 <- NULL  # Remove catch-all topic
df.publication <- df
df.publication$publication <- factor(regmatches(row.names(df), regexpr("^[^_]+", row.names(df))), 
                                     labels=c("Al-Ahram English", "Daily News Egypt", "Egypt Independent"))

# Create correlation matrix
cors <- cor(df)
rownames(cors) <- topic.keys.result$short.names[-20]
colnames(cors) <- topic.keys.result$short.names[-20]

# Create cluster object from matrix
cor.cluster <- hclust(dist(cors), "ward")
cor.dendro <- as.dendrogram(cor.cluster)  # Convert cluster to dendrogram


#----------------------------------------
# Plot dendrogram and topic proportions
#----------------------------------------
# Scaling and normalizing functions
# Scale the data between exactly 0 and 1
scale.data <- function(X) {
  (X - min(X)) / diff(range(X))
}

# Square root of the column sums
sqrt.sum <- function(x) {
  sqrt(sum(x))
}

# Reorder topics to match the dendrogram
topic.order <- order.dendrogram(cor.dendro)  # Get order of dendrogram
column.names <- colnames(df)  # Get column names from publication-free data frame
topic.order <- column.names[topic.order]  # Get correct column order

# Create data frame for manually plotting the dendrogram
dendro <- ggdendro:::dendrogram_data(cor.dendro)  # Extract ggplot data frame from dendrogram object
dendro$segments$yend[dendro$segments$yend < 0.8] <- 0.8  # Cut ends of leaves off to make room for bar charts

# Create data frame for plotting different proprotions
# Proportion means
topic.means.wide <- ddply(df.publication, ~ publication, colwise(mean))
topic.means.long <- melt(topic.means.wide, id="publication", variable.name="topic", value.name="mean.prop")

# Square root of column sums
topic.sqrt.wide <- ddply(df.publication, ~ publication, colwise(sqrt.sum))
topic.sqrt.long <- melt(topic.sqrt.wide, id="publication", variable.name="topic", value.name="sqrt.sum")

# Combine into one data frame
plot.data <- topic.means.long
plot.data$topic <- factor(plot.data$topic, levels=topic.order, ordered=TRUE)
plot.data$scaled0to1 <- scale.data(plot.data$mean.prop) / 2  # Scale data
plot.data$sqrt.sum <- topic.sqrt.long$sqrt.sum / 2.4

# Add spaces after legend titles to help with spacing
plot.data$publication <- paste(plot.data$publication, "   ")

cluster.min <- c(0.5, 10.5)
cluster.max <- c(5.5, 14.5)

# Plot the dendrogram and bar plots
p <- ggplot() + geom_rect(aes(xmin=cluster.min, xmax=cluster.max, ymin=-Inf, ymax=Inf), fill="lightgrey", alpha=0.7) + 
  geom_segment(data=segment(dendro), aes(x=x, y=y, xend=xend, yend=yend)) +
  theme_bw() + coord_flip() + 
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
        panel.background = element_blank(), axis.title.x = element_blank(), 
        axis.title.y = element_blank(), axis.text.x = element_blank(), 
        axis.line = element_blank(), axis.ticks = element_blank(),
        panel.border = element_blank(), legend.position="bottom", legend.key.size = unit(.7, "line")) + 
  #theme(axis.text.y=element_text(hjust=1, size=13)) +
  scale_x_discrete(labels=dendro$labels$label) +
  scale_fill_manual(values=c("#e41a1c", "#377eb8", "#e6ab02"), name="") + 
  #geom_bar(data=plot.data, aes(topic, sqrt.sum, fill=publication), stat="identity", width=.5)
  geom_bar(data=plot.data, aes(topic, scaled0to1, fill=publication), stat="identity", width=.5)

ggsave(plot=p, filename="../Output/plot_dendro.pdf", width=7, height=5, units="in")
system("rm Rplots.pdf")  # Something---maybe ggdendro---is making this file!

#-----------------
# Create arcplot
#-----------------
# Get pieces for arcplot
# suppressPackageStartupMessages(library(arcdiagram))
# values <- colSums(cors)  # Sum of correlations for edge values
# edges <- melt(cors)  # Convert to long
# edges <- edges[edges[, 3] >= 0.1, ]  # Get rid of negative and small correlations
# colnames(edges) <- c("Source","Target","Weight")
# edgelist <- as.matrix(edges[, 1:2])  # Create edgelist

# # Replicate the dendrogram order
# arcs.order <- order.dendrogram(cor.dendro)

# # Plot the arcplot
# pdf(file="../Output/arcs.pdf", width=3, height=5)
# arcplot(edgelist, lwd.arcs=20 * edges[,3], 
#         show.nodes=TRUE, sorted=TRUE, ordering=arcs.order, 
#         show.labels=FALSE, col.arcs="#ff7f00", horizontal=FALSE)
# dev.off()

# Bonus!
# This will rotate the graph by 180°, but it doesn't work in RStudio, and it can't flip the graph.
# So we need to use Photoshop to get the arcs and dendrogram to align
# library(grid)
# cap <- grid.cap()
# grid.newpage()
# grid.raster(cap, vp=viewport(angle=180))