# ��� ����������� ������� �� ����. - ���. ����. ����������!
setwd("C:/Users/������� �������/Dropbox/Crypto meetings/Arbitrage_in_R") # ��������� ���� ������� �����
getwd()

##########  ������ ������ ���������  ############

# ������� ����������
rm(list=ls())

# ������ ����������
control <- read.table("control.csv", sep=",", h=T)
control

# ��������� ��� ��������
print("OUR amount in $")
VOLUME.limit.our <- control$Amount_USD

# �������� �� BUY
a <- control$Buy_percent/100
# �������� �� SELL
b <- control$Sell_percent/100

# ���-�� ����� ��� �������
k.max <- control$k_max

# �������� ������ � ��������, ���������� � ������ ���� � ��������
BUY.RAW <- read.table("ask.csv", sep=",")
names(BUY.RAW) <- c("BUY.price","BUY.btc")
BUY.RAW$BUY.volume.USD <- BUY.RAW$BUY.price*BUY.RAW$BUY.btc
BUY.SORT <- BUY.RAW[order(BUY.RAW$BUY.price),]
#BUY.SORT
SELL.RAW <- read.table("bid.csv", sep=",")
names(SELL.RAW) <- c("SELL.price","SELL.btc")
SELL.RAW$SELL.volume.USD <- SELL.RAW$SELL.price*SELL.RAW$SELL.btc
SELL.SORT <- SELL.RAW[rev(order(SELL.RAW$SELL.price)),]
#SELL.SORT

# ����, �� ������� ��  ����� ������ BTC � ������ ��������
BUY.price <- (1+a)*BUY.SORT$BUY.price
# ����� BTC � ��������, ������� �� ����� ������
BUY.volume.simple <- BUY.SORT$BUY.volume.USD
# ����, �� ������� ��  ����� ������� BTC � ������ ��������
SELL.price <- (1-b)*SELL.SORT$SELL.price
# ����� BTC � ��������, ������� �� ����� �������
SELL.volume.simple <- SELL.SORT$SELL.volume.USD

# ��������� �������� BUY � SELL
BUY.volume <- BUY.volume.simple[1]
for (h in 2:length(BUY.volume.simple)) BUY.volume[h] <- BUY.volume[h-1]+BUY.volume.simple[h]
SELL.volume <- SELL.volume.simple[1]
for (s in 2:length(SELL.volume.simple)) SELL.volume[s] <- SELL.volume[s-1]+SELL.volume.simple[s]

# ��������� ���� ����-����� (������������)
BUY <- data.frame(BUY.price,BUY.volume)
#BUY
SELL <- data.frame(SELL.price,SELL.volume)
#SELL

# �������� BUY � SELL �� ������ � USD
png(file="Cumulative curves.png", bg="transparent") # ������ � ����
plot(BUY.price,BUY.volume, type="l", xlab="Price in USD", ylab="Volume in USD", xlim=c(min(BUY.price,SELL.price),max(BUY.price,SELL.price)), ylim=c(min(BUY.volume,SELL.volume),max(BUY.volume,SELL.volume)), col="red", main="Cumulative curves")
lines(SELL.price,SELL.volume, col="green")
dev.off() # �������� ���� �������

# ���������� - ����� �� ������
BUY.price.min <- min(BUY$BUY.price)
SELL.price.max <- max(SELL$SELL.price)
if (BUY.price.min >= SELL.price.max) stop("NO DEAL!") else print("WE'll DEAL!")

# ���������� "�������" �������
number.buy <- nrow(BUY[BUY$BUY.price < SELL.price.max,])
number.sell <- nrow(SELL[SELL$SELL.price > BUY.price.min,])

# ���������� ������������ ����� ������, ������� �� �������� ������
VOLUME.limit.max <- min(BUY$BUY.volume[number.buy],SELL$SELL.volume[number.sell])
#VOLUME.limit.max1 <- min(BUY$BUY.volume[nrb],)
# � ��������� ��������� ��� 
VOLUME.limit <- min(VOLUME.limit.max,VOLUME.limit.our)
#VOLUME.limit <- VOLUME.limit.max
print("The limit amount:")
VOLUME.limit

# ���������� ��� �������
VOLUME.CURR <- 0
Profit.USD <- 0
Amount.USD <- 0
Function.Prise.weight.BUY <- 0
Function.Prise.weight.SELL <- 0

for (k in 1:k.max) {
  VOLUME.CURR <- k/k.max*VOLUME.limit
  # ������� ������� ������� BUY ���� � ������ ������� �������
  i <- 1
  MINUS <- BUY.volume.simple[i]*BUY$BUY.price[i]
  while (BUY$BUY.volume[i]<VOLUME.CURR-1) {
    i <- i+1
    MINUS <- MINUS+BUY.volume.simple[i]*BUY$BUY.price[i]
  }
  #if (BUY.GOOD$BUY.volume[j]>VOLUME.CURR) MINUS <- MINUS-(BUY.GOOD$BUY.volume[i]-VOLUME.CURR)*BUY.GOOD$BUY.price[i]
  MINUS <- MINUS-(BUY$BUY.volume[i]-VOLUME.CURR)*BUY$BUY.price[i]
  # ������� ������� BUY ����
  Function.Prise.weight.BUY[k] <- MINUS/VOLUME.CURR
  # ������� ������� ������� SELL ���� � ������ ������� �������
  j <- 1
  PLUS <- SELL.volume.simple[j]*SELL$SELL.price[j]
  while (SELL$SELL.volume[j]<VOLUME.CURR-1) {
    j <- j+1
    PLUS <- PLUS+SELL.volume.simple[j]*SELL$SELL.price[j]
  }
  #if (SELL.GOOD$SELL.volume[j]>VOLUME.CURR) PLUS <- PLUS-(SELL.GOOD$SELL.volume[j]-VOLUME.CURR)*SELL.GOOD$SELL.price[j]
  PLUS <- PLUS-(SELL$SELL.volume[j]-VOLUME.CURR)*SELL$SELL.price[j]  
  # ������� ������� SELL ����
  Function.Prise.weight.SELL[k] <- PLUS/VOLUME.CURR
  # �����
  PERCENT <- (Function.Prise.weight.SELL[k]-Function.Prise.weight.BUY[k])/Function.Prise.weight.BUY[k]
  PROFIT <- PERCENT*VOLUME.CURR
  Profit.USD[k] <- PROFIT
  Amount.USD[k] <- VOLUME.CURR
}

# ���������������� �� ������ ����
png(file="Price-Amount relation.png", bg="transparent") # ������ � ����
plot(Amount.USD, Function.Prise.weight.BUY, ylab="Prise.USD", ylim=c(min(Function.Prise.weight.BUY),max(Function.Prise.weight.SELL)), type="l", col="red",  main="Price-Amount relation")
lines(Amount.USD, Function.Prise.weight.SELL, col="green")
dev.off() # �������� ���� �������

# ����� �����������
ALL.plot.data <- data.frame(Amount.USD,Profit.USD)
#ALL.plot.data
png(file="Profit-Amount relation.png", bg="transparent") # ������ � ����
plot(ALL.plot.data, type="l", main="Profit-Amount relation")
dev.off() # �������� ���� �������
print("THE MAXIMAL PROFIT AND OPTIMAL AMOUNT")
BEST.plot.data <- ALL.plot.data[ALL.plot.data$Profit.USD == max(Profit.USD),]
round(BEST.plot.data,0)
# ������ ���������� � ����
write.table(file="maxprofit.csv", round(BEST.plot.data,0), row.names=F, sep=",", quote=F)

# ������ ����������� ������� BUY
BUY.OPTIMAL <- BUY[BUY$BUY.volume < BEST.plot.data[[1]],]
BUY.SORT[1:length(BUY.OPTIMAL$BUY.volume)+1,]
# ������ ���������� � ����
write.table(file="buy_orders.csv", BUY.SORT[1:length(BUY.OPTIMAL$BUY.volume)+1,], row.names=F, sep=",", quote=F)

# ������ ����������� ������� SELL
SELL.OPTIMAL <- SELL[SELL$SELL.volume < BEST.plot.data[[1]],]
SELL.SORT[1:length(SELL.OPTIMAL$SELL.volume)+1,]
# ������ ���������� � ����
write.table(file="sell_orders.csv", SELL.SORT[1:length(SELL.OPTIMAL$SELL.volume)+1,], row.names=F, sep=",", quote=F)

# ������� �������� ����������
TOBEST.plot.data <- ALL.plot.data[ALL.plot.data$Amount.USD <= BEST.plot.data[[1]],]
TOBEST.plot.data$PERCENT.per.Amount <- TOBEST.plot.data$Profit.USD*100/TOBEST.plot.data$Amount.USD
png(file="Profit Percent-Amount relation.png", bg="transparent") # ������ � ����
plot(TOBEST.plot.data$PERCENT.per.Amount~TOBEST.plot.data$Amount.USD, xlab="Amount.USD", ylab="Percent", type="l", main="Amount-Profit Percent relation")
dev.off() # �������� ���� �������

################### The END #######################################

