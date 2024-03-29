##-----##
# Oeconomica's Entrepreneurship, Innovation & Antitrust Cohort, 2020–2021
##-----##

# Everything you need to run this code (data and instructions) is here:
# https://github.com/gelkouh/eia-oeconomica

# This snippet of code is a little loop that makes my code work on your computer
root <- getwd()
while(basename(root) != "eia-oeconomica") { # this is the name of your project directory you want to use
  root <- dirname(root)
}

# This line runs the script in your data.R file so that each person can have
# their data in a different place because everyone's file structure will be 
# a little different
source(file.path(root, "data.R"))

# This is the specific folder we want to access data from
ddir <- file.path(ddir, 'eia cohort project')

# Loading the packages we want
if (!require(tidyverse)) install.packages('tidyverse')
library(tidyverse)
library(readxl)
if (!require(scales)) install.packages('scales')
library(scales)
if (!require(reshape2)) install.packages('reshape2')
library(reshape2)
if (!require(cowplot)) install.packages('cowplot')
library(cowplot)
if (!require(plm)) install.packages('plm')
library(plm) # masks lag from dplyr (so we need to specify dplyr::lag)
if (!require(stargazer)) install.packages('stargazer')
library(stargazer) 

##-----##
# Load data and select columns of interest
##-----##

loadRData <- function(fileName){
  # Loads RData file and returns it
  load(fileName)
  get(ls()[ls() != "fileName"])
}

# Panel Study of Entrepreneurial Dynamics, PSED II, United States, 2005-2011 (ICPSR 37202)
# http://www.psed.isr.umich.edu/psed/home
df_icpsr <- loadRData(file.path(ddir, 'ICPSR_37202', 'DS0003', '37202-0003-Data.rda'))

# Each nascent entrepreneur is identified by a unique SAMPID value
# There are 1214 entrepreneurs represented, one for each row

# There were screener interviews and six waves of followup interviews conducted 
# The screener interviews were conducted from September 2005 to February 2006.
# Wave A interviews were conducted from September 2005 to March 2006.
# Wave B interviews were conducted one year later, from October 2006 to March 2007. 
# Wave C interviews were conducted two years later, from October 2007 to May 2008. 
# Wave D interviews were conducted three years later, from October 2008 to April 2009. 
# Wave E interviews were conducted four years later, from October 2009 to April 2010. 
# Wave F interviews were conducted five years later, from October 2010 to April 2011.

# Multiply any variable by its wave's weight if generating summaries of all observations
# Make sure weights are recentered to have mean = 1 if a subset is used

# Variables:
# Industry (NAICS): AA1
# Why do you want to start this business: AA2A, AA2B
# What prompted you to start this new business: AA5A, AA5B
# What are the one or two main problems involved in starting this new business? (compare number of patents to market competition response): AA6A, AA6B)
# Did this new business emerge from your current work activity? (compare to capital expenditures, etc.): AA9
# Question related to new business's being sponsored by eisting business: AA10
# Question related to technical and scientific expertise of start-up team is important: AF8
# How many years of work experience have you had in the industry: AH11_1
# BA50: 1 == new firm; 2 == active start-up; 3 == quit

##-----##

# NBER Manufacturing 
# https://www.nber.org/research/data/nber-ces-manufacturing-industry-database
df_nber_naics5811 <- read_csv(file.path(ddir, 'NBER Manufacturing', 'naics5811.csv'))

##-----##

# Connecting Outcome Measures in Entrepreneurship, Technology, and Science (COMETS) database
# https://www.kauffman.org/entrepreneurship/research/comets/
# Note: read_csv works with zipped files
df_comets_patents <- read_csv(file.path(ddir, 'COMETS', 'All CSV', 'Patent CSV', 'patents_v2.csv.zip')) %>%
  select(c('patent_id', 'grant_date', 'patent_title'))
df_comets_patent_cite_counts <- read_csv(file.path(ddir, 'COMETS', 'All CSV', 'Patent CSV', 'patent_cite_counts_v2.csv.zip'))
df_comets_patent_us_classes <- read_csv(file.path(ddir, 'COMETS', 'All CSV', 'Patent CSV', 'patent_us_classes_v2.csv.zip')) %>%
  select(c('patent_id', 'us_class'))
# This failed for some reason: 
# df_comets_patent_assignees <- read_csv(file.path(ddir, 'COMETS', 'All CSV', 'Patent CSV', 'patent_assignees_v2.csv.zip')) %>%
#   select(c('patent_id', 'org_type'))
df_comets_patent_zd_cats <- read_csv(file.path(ddir, 'COMETS', 'All CSV', 'Patent CSV', 'patent_zd_cats_v2.csv.zip')) %>%
  rename(patent_id = patent) %>%
  select(c('patent_id', 'zd'))

# Note: amount is NA for all values (probably to anonymize the data)
df_comets_grants <- read_csv(file.path(ddir, 'COMETS', 'All CSV', 'Grant CSV', 'grants_v2.csv.zip')) %>%
  select(c('grant_num', 'grant_agency', 'start_date', 'end_date', 'amount'))
df_comets_grantee_orgs <- read_csv(file.path(ddir, 'COMETS', 'All CSV', 'Grant CSV', 'grantee_orgs_v2.csv.zip')) %>%
  select(c('grant_num', 'grant_agency', 'org_type'))
df_comets_grant_zd_cats <- read_csv(file.path(ddir, 'COMETS', 'All CSV', 'Grant CSV', 'grant_zd_cats_v2.csv.zip')) %>%
  select(c('grant_num', 'grant_agency', 'zd'))

df_comets_patent <- df_comets_patents %>%
  left_join(df_comets_patent_cite_counts, by = 'patent_id') %>%
  left_join(df_comets_patent_us_classes, by = 'patent_id') %>%
  left_join(df_comets_patent_zd_cats, by = 'patent_id')

df_comets_grant <- df_comets_grants %>%
  left_join(df_comets_grantee_orgs, by = 'grant_num') %>%
  left_join(df_comets_grant_zd_cats, by = 'grant_num')

# Subsetting
subset_df <- function(df, n) {
  set.seed(60637)
  df[sample(1:nrow(df), n, replace=FALSE),]
}

##-----##
# Exploratory Data Analysis (make a new script with this code when done this step)
##-----##

## Finding: The US and international patent classification are not informative
## Solution: either find the complete codebook for patent classification, or 
## study the Zucker-Darby Science and Technology Area Category first

# see which ZD category has more patents
patent_zd_sum <- df_comets_patent_subset %>%
  group_by(zd)%>%
  summarize(count=n())%>%
  arrange(desc(count))

p1 <- ggplot(df_comets_patent_subset, aes(x = zd)) +
  geom_bar()

# see which ZD category has more grants
grant_zd_sum <- df_comets_grant_subset %>%
  group_by(zd)%>%
  summarize(count=n())%>%
  arrange(desc(count))

p2 <- ggplot(df_comets_grant_subset, aes(x = zd)) +
  geom_bar()

# compare the results
plot_grid(p1, p2, labels = c("patents","grants"))

# Capital expenditures in different industries 

df_invest_by_sic <- df_nber_sic5811 %>%
  group_by(sic) %>%
  summarize(invest_per_equip_mean = mean(invest/equip), sic_name, year) %>%
  arrange(desc(invest_per_equip_mean))

ggplot(df_invest_by_sic, aes(x = sic, y = invest_per_equip_mean)) +
  geom_col() +
  theme_void()

# Merge ICPSR on SIC codes (AA1A)
df_icpsr_selected_cols <- df_icpsr_followups %>%
  rename(naics = AA1) 

icpsr_nber <- merge(df_icpsr_selected_cols, df_nber_naics5811, on = 'naics')
View(icpsr_nber)
