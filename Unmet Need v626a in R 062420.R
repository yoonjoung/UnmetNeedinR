# Unmet need v626a
# Kristin Bietsch, PhD
# Avenir Health
# 06/24/20
# Translated from Stata Code by Sarah Bradely (https://dhsprogram.com/topics/Unmet-Need.cfm#:~:text=What%20is%20unmet%20need%3F,and%20has%20changed%20over%20time.)

library(survey)
library(tibble)
library(dplyr)
library(tidyr)
library(haven)
library(stringr)
library(questionr)
options(scipen=999)



# Set your working directory to read in file
setwd("C:/Users/KristinBietsch/files/DHSLoop")

#####################################################################
# Read in data
#####################################################################

women <- read_dta("HTIR52FL.DTA")

#To change cutoffs for postpartum amenorrhea duration, change "cutofflow" and "cutoffhigh" variables below
women <- women %>% mutate(cutofflow=24,
                          cutoffhigh=60,
                          wgt=v005/1000000,
                          unmet=NA)

#*set up for ever-married samples or those without sexual activity data for single women
#includes Morocco 2003-04 and Turkey 1998
women <- women %>% mutate(unmet=case_when(v502!=1 & (v020==1 | v000=="MA4" | v000=="TR2") ~ 98 ,
                                          is.na(unmet) ~ NA_real_))


#*CONTRACEPTIVE USE
#using to limit if wants no more, sterilized, or declared infecund
#using to space - all other contraceptive users
women <- women %>% mutate(unmet=case_when( is.na(unmet)  & v312!=0 & (v605>=5 & v605<=7) ~ 4,
                                           is.na(unmet) & v312!=0 ~ 3,
                                           is.na(unmet) ~ NA_real_,
                                           TRUE ~ unmet))



#*DETERMINE PREGNANT or PPA
#*gen time since last birth 
women <- women %>% mutate(tsinceb=v008-b3_01)
#* gen time since last period in months from v215
women <- women %>% mutate(tsincep=case_when(v215>=100 & v215<=190 ~ trunc((v215-100)/30),
                                            v215>=200 & v215<=290   ~ trunc((v215-200)/4.3),
                                            v215>=300 & v215<=390 ~ (v215-300),
                                            v215>=400 & v215<=490 ~ (v215-400)*12  ))

#**For women with missing data or "period not returned" on date of last menstrual period, use information from time since last period
#**if last period is before last birth in last 5 years
#**if said "before last birth" to time since last period in the last 5 years
#**select only women who are pregnant or PPA for <24 months

women <- women %>% mutate(pregPPA=case_when(v213==1 | m6_1==96 ~ 1,
                                            (is.na(m6_1) | m6_1==99 | m6_1==97) & tsincep> tsinceb & tsinceb<60 & !is.na(tsincep) & !is.na(tsinceb) ~ 1,
                                            (is.na(m6_1) | m6_1==99 | m6_1==97) & v215==995 & tsinceb<60 & !is.na(tsinceb) ~ 1),
                          pregPPA24=case_when(v213==1 | (pregPPA==1 & tsinceb < cutofflow) ~ 1))


#**wantedness of last birth/current preg
#*current pregnancy
women$wantedlast <- as.numeric(women$v225)
#*recode 'God's will' (country-specific response) as response to wantedness of current pregnancy to treat it as not in need for NI92- 4 needs to be changed to 1
women <- women %>% mutate( wantedlast = case_when(wantedlast==4 & v000=="NI2" ~ 1,
                                TRUE   ~ wantedlast ))

#*last birth
women <- women %>% mutate( wantedlast = case_when((is.na(wantedlast) | wantedlast==9) & v213!=1 ~ m10_1,
                                                  TRUE   ~ wantedlast ))
#*recode 'not sure' and 'don't know' (country-specific responses) to treat them as having need for spacing for some surveys between 1991 and 1994
women$wantedlast <- as.numeric(women$wantedlast)
women <- women %>% mutate( wantedlast = case_when(wantedlast==4 | wantedlast==8 ~ 2,
                                                  TRUE   ~ wantedlast ))





#*UNMET NEED STATUS OF PREGNANT WOMEN OR WOMEN PPA FOR <24 months
#desires birth in <2 years if wanted then
women <- women %>% mutate(unmet=case_when(is.na(unmet) & pregPPA24==1 & wantedlast == 1 ~ 7,
                                          is.na(unmet) & pregPPA24==1 & wantedlast == 2 ~ 1,
                                          is.na(unmet) & 	pregPPA24==1 & wantedlast == 3 ~ 2, 
                                          is.na(unmet) & pregPPA24==1 & (is.na(wantedlast) | wantedlast == 9) ~ 99 ,
                                          TRUE   ~ unmet))



#*NO NEED FOR UNMARRIED WOMEN WHO ARE NOT SEXUALLY ACTIVE
#sexual activity status # KB Note- the stata code says sexact!=1, but the way the missings are handled is different in R, so changing to is missing
women <- women %>% mutate(sexact=case_when(v528>=0 & v528<=30 ~ 1))
women <- women %>% mutate(unmet=case_when(is.na(unmet) & v502!=1 & is.na(sexact) ~ 97,
                                          TRUE   ~ unmet))


#**DETERMINE FECUNDITY
#**Boxes 1-4a only apply to women who are not pregnant and not PPA<24 months
#**Box 1 - applicable only to currently married
#**married 5+ years ago, no children in past 5 years, never used contraception, excluding pregnant and PPA <24 months # KB Note- the stata code says pregPPA24!=1, but the way the missings are handled is different in R, so changing to is missing
women <- women %>% mutate(infec1=case_when(v502==1 & v512>=5 & !is.na(v512) & (tsinceb>59 | is.na(tsinceb)) & v302==0 & is.na(pregPPA24) ~ 1))


#**Box 3
# KB Note: creating the round of DHS
women$dhs_round <- substring(women$v000, 3, 3)
survey_round <- women$v000[1]
survey_year <-women$v007[1]

#**declared infecund on future desires for children
women <- women %>% mutate(infec3=case_when(v605==7 ~ 1))

#*menopausal/hysterectomy on reason not currently using - DHS IV+ surveys only
if (exists("v3a08d",  women)) {
  women <- women %>% mutate(infec3=case_when(v3a08d==1 & (dhs_round== "4" | dhs_round== "5" |  dhs_round== "6" ) ~ 1,
                                             TRUE   ~ infec3))
}
# *Single-response question used in DHSIII surveys
if (exists("v375a",  women)) {
  women <- women %>% mutate(infec3=case_when(v375a==23 & (dhs_round== "3" | dhs_round== "T"  ) ~ 1,
                                             TRUE   ~ infec3))
}
#*Note: q did not exist in DHSII, use reason not intending to use in future
if (exists("v376",  women)) {
  women <- women %>% mutate(infec3=case_when(v376==14 & dhs_round== "2"  ~ 1,
                                             TRUE   ~ infec3))
}
#*special code for hysterectomy for Brazil 1996, Guatemala 1995 and 1998-9  (code 23 = menopausal only)
if (exists("v375a",  women)) {
  women <- women %>% mutate(infec3=case_when(v375a==28 & (v000== "BR3" | v000=="GU3")  ~ 1,
                                             TRUE   ~ infec3))
}
#*country-specific code for Tanzania 1999
if (survey_round== "TZ3" & survey_year== 99) {
  women <- women %>% mutate(infec3=case_when(  s607d==1	  ~ 1,
                                             TRUE   ~ infec3))
}

#*below set of codes are all replacements for reason not using.
#*country-specific code for Cote D'Ivoire 1994
if (survey_round== "CI3" & survey_year== 94) {
  women <- women %>% mutate(infec3=case_when( v007== 94 & v376==23  ~ 1,
                                              TRUE   ~ infec3))
}

#*country-specific code for Gabon 2000
if (survey_round== "GA3") {
  women <- women %>% mutate(infec3=case_when(  s607d==1 ~ 1,
                                               TRUE   ~ infec3))
}
#*country-specific code for Jordan 2002
if (survey_round== "JO4") {
  women <- women %>% mutate(infec3=case_when(  v376==23 | v376==24 ~ 1,
                                                TRUE   ~ infec3))
}
#*country-specific code for Kazakhstan 1999
if ( survey_round== "KK3" & survey_year== 99 ) {
  women <- women %>% mutate(infec3=case_when(  v376==231 ~ 1,
                                               TRUE   ~ infec3))
}
#*country-specific code for Maldives 2009
if (survey_round== "MV5") {
  women <- women %>% mutate(infec3=case_when(  v376==23 ~ 1,
                                               TRUE   ~ infec3))
}
#*country-specific code for Turkey 2003
if (survey_round== "TR4") {
  women <- women %>% mutate(infec3=case_when(  v375a==23 ~ 1,
                                               TRUE   ~ infec3))
}
#*country-specific code for Mauritania
if (survey_round== "MR3" ) {
  women <- women %>% mutate(infec3=case_when(   s607c==1 ~ 1,
                                               TRUE   ~ infec3))
}


#exclude pregnant and PP amenorrheic < 24 months
women <- women %>% mutate(infec3=case_when( pregPPA24==1 ~ NA_real_,
                                            TRUE   ~ infec3))


#**Box 4a
#**menopause/hysterectomy on time since last period
#**hysterectomy has different code for some surveys (but in 3 surveys it means "currently pregnant")
#**never menstruated on time since last period, unless had a birth in the last 5 years
#**time since last birth>= PPA high cutoff and last period was before last birth
#**Never had a birth, but last period reported as before last birth - assume code should have been 994 or 996
#*exclude pregnant and PP amenorrheic < 24 months

women <- women %>% mutate(infec4a=case_when(pregPPA24==1 ~ NA_real_,
                                            v215==994 ~ 1,
                                            v215==993 & v000 != "TR4" & v000 != "UG3" & v000 != "YE2" ~ 1,
                                            v215==996 & (tsinceb>59 | is.na(tsinceb)) ~ 1,
                                            v215==995 & tsinceb>=cutoffhigh & !is.na(tsinceb) ~  1,
                                            v215==995 & is.na(tsinceb) ~ 1))

#**Box 4b for women who are PPA for 24+ months
#*Time since last period is >=6 months and not PPA
women <- women %>% mutate(infec4b=case_when(tsincep>=6 & !is.na(tsincep) & is.na(pregPPA) ~ 1))

# **INFECUND
women <- women %>% mutate(unmet=case_when(is.na(unmet) & (infec1==1 | infec3==1 | infec4a==1 | infec4b==1) ~ 9,
                                          TRUE   ~ unmet))

#**FECUND WOMEN
#*wants within 2 years
women <- women %>% mutate(unmet=case_when(is.na(unmet) & v605==1 ~ 7,
                                          TRUE   ~ unmet))

#*special code: treat 'up to god' (country-specific response) as not in need for India (different codes for 1992-3 and 1998-9)
if (survey_round== "IA3" ) {
  women <- women %>% mutate(unmet=case_when(is.na(unmet) & v605==9 ~ 7,
                                            TRUE   ~ unmet))
}
if (survey_round== "IA2" ) {
  women <- women %>% mutate(unmet=case_when(is.na(unmet) & v602==6  ~ 7,
                                            TRUE   ~ unmet))
}
#*wants in 2+ years, wants undecided timing, or unsure if wants
#*special code for Lesotho
if (survey_round== "LS5" ) {
  women <- women %>% mutate(v605=case_when(is.na(v605)   ~ 4,
                                            TRUE   ~ v605))
}
women <- women %>% mutate(unmet=case_when(is.na(unmet) & v605>=2 & v605<=4 ~ 1,
                                          TRUE   ~ unmet))

#*wants no more
women <- women %>% mutate(unmet=case_when(is.na(unmet) & v605==5 ~ 2,
                                          is.na(unmet) ~ 99,
                                          TRUE   ~ unmet))

# ** Turkey 2003 -  section 6 only used if cluster even, HHnum even or cluster odd, HHnum odd
if (survey_round== "TR4" ) {
  women$test1 <- women$v001 %% 2 
  women$test2 <- women$v002 %% 2 
  women$match <- ifelse(women$test1==women$test2, 1, 0)
  
  women <- women %>% filter(match==1)
}

prop.table(wtd.table(women$unmet, weights = women$wgt))
wtd.table(women$unmet, weights = women$wgt)
table(women$unmet)


