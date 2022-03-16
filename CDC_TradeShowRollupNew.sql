-- SP: CDC_TradeShowRollUpNew
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE         Procedure [dbo].[CDC_TradeShowRollUpNew]
(
	@StartDate		DATETIME='1/1/2008'
)
AS
/*	ChangeLog:
	2/15/2012 : Added MSRP to results for TSR. : Joey B. 
	8/13/2012 : Made change to include dropship items : Joey B.
	11/9/2016 : Made changes to include coupons, discounts, & TXB : Joey B.
	2/21/2018 : Added Online Quantity and Selling Price: Trey G.
*/

	----------testing
	--declare @StartDate datetime
	--set @StartDate = '1/1/2008'

	DECLARE @i_StartDate 		DATETIME--purchases start date
	DECLARE @i_EndDate 			DATETIME--purchases end date
	DECLARE @i_SalesEnding 		DATETIME--sales thru
	DECLARE @i_ReportType 		INT		--assortments=1, titles=2

SELECT @i_StartDate=@StartDate,@i_EndDate=CAST(CONVERT(VARCHAR,GetDate(),101)AS DATETIME),@i_SalesEnding=CAST(CONVERT(VARCHAR,GetDate(),101)AS DATETIME)

/*CREATE TABLES & INDEXES TO DO THE WORK*/
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CDC_SDV_PENDING]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	DROP TABLE CDC_SDV_PENDING

CREATE TABLE CDC_SDV_PENDING (
	[VendorID] [varchar] (10) NOT NULL ,
	[ReorderVendorID] [varchar] (10) NOT NULL ,
	[ItemCode] [varchar] (20) NOT NULL ,
	[Parent] [varchar] (8) NULL ,
	[ISBN] [varchar] (13) NULL ,
	[ProductType] [VARCHAR](20) NULL,
	[Buyer] [VARCHAR](50) NULL,
	[SectionCode] [VARCHAR](10)  NULL,
	[Title] [varchar] (70)  NULL ,
	[Cost] [money]  NULL ,
	[Price] [money]  NULL ,
	[MSRP] [money]  NULL ,
	[QtyShipped] [int]  NULL ,
	[QtyTrans] [int]  NULL ,
	[QtyDamaged] [int] NULL,
	[QtySold] [int]  NULL ,
	[QtyReturned] [int]  NULL ,
	[RegisterPrice] [money]  NULL ,
	[ExtendedAmt] [money]  NULL ,
	[OnHand] [int]  NULL ,
	[AmtInvoiced] [money] NULL ,
	[Reorderable]	[CHAR](1) NULL,
	[LastPO] [char] (6) NULL ,
	[LastReceived] [smalldatetime] NULL ,
	[FirstReceived] [smalldatetime] NULL ,
	[SchemeID] [Varchar] (20) NULL,
	[TTBInv] [int] NULL,
	[FOBItem] [varchar] (250) NULL,
	[FOBPO] [varchar] (250) NULL,
	[Publisher] [varchar] (250) NULL,
	[Author] [varchar] (250) NULL
)

CREATE  CLUSTERED  INDEX [IDX_TEMP_PENDING] ON CDC_SDV_PENDING ([VendorID], [ItemCode])

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CDC_SDV_WORK]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	DROP TABLE CDC_SDV_WORK

CREATE TABLE CDC_SDV_WORK (
	[VendorID] [varchar] (10) NOT NULL ,
	[ReorderVendorID] [varchar] (10) NOT NULL ,
	[ItemCode] [varchar] (20) NOT NULL ,
	[Parent] [varchar] (8) NULL ,
	[ISBN] [varchar] (13) NULL ,
	[ProductType] [VARCHAR](20) NULL,
	[Buyer] [VARCHAR](50) NULL,
	[SectionCode] [VARCHAR](10)  NULL,
	[Title] [varchar] (70)  NULL ,
	[Cost] [money]  NULL ,
	[Price] [money]  NULL ,
	[MSRP] [money]  NULL ,
	[QtyShipped] [int]  NULL ,
	[QtyTrans] [int]  NULL ,
	[QtyDamaged] [int] NULL,
	[QtySold] [int]  NULL ,
	[QtyReturned] [int]  NULL ,
	[QtyMarkedDown] [int]  NULL ,
	[RegisterPrice] [money]  NULL ,
	[ExtendedAmt] [money]  NULL ,
	[OnHand] [int]  NULL ,
	[AmtInvoiced] [money] NULL ,
	[Reorderable]	[CHAR](1) NULL,
	[LastPO] [char] (6) NULL ,
	[LastReceived] [smalldatetime] NULL ,
	[FirstReceived] [smalldatetime] NULL ,
	[PctSold] AS (CASE ISNULL(QtyShipped,0) WHEN 0 THEN ISNULL(QtySold,0)ELSE (convert(float,[QtySold]) / convert(float,[QtyShipped]) * 100)END) ,
	[SchemeID] [Varchar] (20) NULL,
	[TTBInv] [int] NULL,
	[FOBItem] [varchar] (250) NULL,
	[FOBPO] [varchar] (250) NULL,
	[Publisher] [varchar] (250) NULL,
	[Author] [varchar] (250) NULL,
	[Coupons] [int]  NULL ,
	[CouponAmt] [money]  NULL ,
	[QtyDisc] [int]  NULL ,
	[DiscAmt] [money]  NULL 
)

CREATE  CLUSTERED  INDEX [IDX_TEMP_PIG] ON CDC_SDV_WORK ([VendorID], [ItemCode])

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CDC_SDV_SALES]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	DROP TABLE CDC_SDV_SALES

CREATE TABLE CDC_SDV_SALES(ExtendedAmt MONEY,RegisterPrice MONEY,QuantitySold INT,ItemCode VARCHAR(20))
CREATE  CLUSTERED  INDEX [IDX_PIG_SALES] ON CDC_SDV_SALES( [ItemCode])

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CDC_SDV_SalesData]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	DROP TABLE CDC_SDV_SalesData

CREATE TABLE CDC_SDV_SalesData(ExtendedAmt MONEY,RegisterPrice MONEY,QuantitySold INT,Returned INT,Coupons INT,CouponAmt money,MarkedDown INT,QtyDisc INT,DiscAmt money,ItemCode VARCHAR(20))
CREATE  CLUSTERED  INDEX [IDX_PIG_SalesData] ON CDC_SDV_SalesData( [ItemCode])

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CDC_SDV_RETURNS]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	DROP TABLE CDC_SDV_RETURNS

CREATE TABLE CDC_SDV_RETURNS(Returned INT,ItemCode VARCHAR(20))
CREATE  CLUSTERED  INDEX [IDX_PIG_RETS] ON CDC_SDV_RETURNS ( [ItemCode])

--create temp table to hold shipment history instead of using table function.  this cuts the runtime from 30 min to 5.....
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#ShipHist]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	DROP TABLE #ShipHist
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#ILSRcvHist]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	DROP TABLE #ILSRcvHist



create table #ShipHist(QtyShipped int, ItemCode char(20), DropShip int)
CREATE  CLUSTERED  INDEX [IDX_items] ON #ShipHist ( [ItemCode])
create table #ILSRcvHist(QtyRcvd int, ItemCode char(20))
CREATE  CLUSTERED  INDEX [IDX_items] ON #ILSRcvHist ( [ItemCode])

insert into #ShipHist
SELECT SUM(ISNULL(sd.QTY,0)) AS QtyShipped, sd.ItemCode, case when (sh.dropshipment)= 0 then 0 else 1 end 
FROM ReportsData..ShipmentDetail sd with (nolock) INNER JOIN ReportsData..ShipmentHeader sh with (nolock) on sh.transferid=sd.transferid
	inner join ReportsData..locations l with (nolock) on l.locationno=sh.fromlocationno and (locationtype='R' or locationtype = 'C')
	join reportsdata..locations ls with (nolock) on ls.locationno = sh.tolocationno and ls.locationtype = 'S' 
WHERE sd.DateReceived BETWEEN @i_StartDate AND DATEADD(day,1,@i_EndDate) 
	AND NOT EXISTS ( SELECT distinct ItemCode FROM ReportsData..InventoryTransfers with (nolock) WHERE FromLocationNo=sh.FromLocationNo and ToLocationNo=sh.ToLocationNo and TransferID=sh.TransferID and itemCode=sd.ItemCode)
GROUP BY sd.ItemCode,case when (sh.dropshipment)= 0 then 0 else 1 end 

insert into #ILSRcvHist
select distinct sum(isnull(r.total_qty,0)), r.item from (
	select sum(isnull(rc.total_qty,0))[total_qty], right('00000000000000000000' + rc.item, 20) [item]
	from rils_data..receipt_detail rc with (nolock)
	where rc.company <> 'SUP' and right('00000000000000000000' + rc.item, 20) not in (select itemcode from #ShipHist) group by right('00000000000000000000' + rc.item, 20)
	union
	select sum(isnull(ar.total_qty,0))[total_qty], right('00000000000000000000' + ar.item, 20)[item]
	from rils_data..AR_RECEIPT_DETAIL ar with (nolock)
	where ar.company <> 'SUP' and right('00000000000000000000' + ar.item, 20) not in (select itemcode from #ShipHist) group by right('00000000000000000000' + ar.item, 20))r
group by r.item

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Received]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	DROP TABLE #Received
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#LastProcessedDate]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	DROP TABLE #LastProcessedDate
----set received dates and parent......
/*Next for Last Received*/
create table #Received (itemcode char(20), firstreceived datetime, lastReceived datetime, parent varchar(5), rcvdqty int)
CREATE  CLUSTERED  INDEX [IDX_items] ON #Received ( [ItemCode])

insert into #Received 
select distinct r.ItemCode,min(r.firstreceived),max(r.lastReceived),r.Parent,isnull(sum(r.RcvdQty),0)
from (
	select distinct sd.itemcode [ItemCode], min(sd.ProcessDate)[firstreceived],max(sd.ProcessDate)[lastReceived], 'SR' [Parent],isnull(SUM(sd.Qty),0)[RcvdQty]
	from ReportsData..SR_Header_Historical sh with (nolock) inner join ReportsData..SR_Detail_Historical sd with (nolock)
		on sh.BatchID = sd.BatchID
	where sh.ShipmentType in ('W')  
	group by sd.ItemCode
	union
	select distinct sd.itemcode [ItemCode], min(sd.ProcessDate)[firstreceived],max(sd.ProcessDate)[lastReceived], 'SR' [Parent],isnull(SUM(sd.Qty),0)[RcvdQty]
	from ReportsData..SR_Header sh with (nolock) inner join ReportsData..SR_Detail sd with (nolock)
		on sh.BatchID = sd.BatchID
	where sh.ShipmentType in ('W')   
	group by sd.ItemCode) r
group by r.ItemCode,r.Parent

insert into #Received 
select distinct r.ItemCode,min(r.firstreceived),max(r.lastReceived),r.Parent,isnull(sum(r.RcvdQty),0)
from (
	select distinct sd.itemcode [ItemCode],min(sd.ProcessDate)[firstreceived],max(sd.ProcessDate)[lastReceived],'DS' [Parent],isnull(SUM(sd.Qty),0)[RcvdQty]
	from ReportsData..SR_Header sh with (nolock) inner join ReportsData..SR_Detail sd with (nolock)
		on sh.BatchID = sd.BatchID
	where sh.ShipmentType in ('R')   
	group by sd.ItemCode
	union
	select distinct sd.itemcode [ItemCode], min(sd.ProcessDate)[firstreceived],max(sd.ProcessDate)[lastReceived], 'DS' [Parent],isnull(SUM(sd.Qty),0)[RcvdQty]
	from ReportsData..SR_Header_Historical sh with (nolock) inner join ReportsData..SR_Detail_Historical sd with (nolock)
		on sh.BatchID = sd.BatchID
	where sh.ShipmentType in ('R')   
	group by sd.ItemCode) r
group by r.ItemCode,r.Parent
	

insert into #received
	select wr.ItemCode,min(wr.firstrecv),max(wr.lastrecv),wr.Parent,sum(wr.RcvdQty) from (
	select right('00000000000000000000' + item, 20)[ItemCode],min(receipt_date)[firstrecv],max(receipt_date)[lastrecv], ' ' [Parent],isnull(SUM(TOTAL_QTY),0)[RcvdQty]
	from rILS_data..RECEIPT_DETAIL
	where right('00000000000000000000' + item, 20) not in (select distinct itemcode from #received) group by right('00000000000000000000' + item, 20)
	union
	select right('00000000000000000000' + item, 20)[ItemCode],min(receipt_date)[firstrecv],max(receipt_date)[lastrecv], ' ' [Parent],isnull(SUM(TOTAL_QTY),0)[RcvdQty]
	from rILS_data..AR_RECEIPT_DETAIL
	where right('00000000000000000000' + item, 20) not in (select distinct itemcode from #received) group by right('00000000000000000000' + item, 20))wr
	group by wr.ItemCode,wr.Parent
	
insert into #received
	select distinct rd.ItemCode,min(rh.DistributionPostedDate),max(rh.DistributionPostedDate), 'DR' [Parent],isnull(SUM(rd.QtyCounted),0)[RcvdQty]
	from ReportsData..ReceiveDetail rd join ReportsData..ReceiveHeader rh on rd.Receiver=rh.Receiver
	where rh.distributionposteddate > @i_StartDate and rd.itemcode not in (select distinct itemcode from #received)
	group by rd.ItemCode

select distinct itemcode,cast(min(firstreceived)as smalldatetime)[firstRcvd],cast(max(lastReceived)as smalldatetime)[LastRcvd],parent
into #LastProcessedDate
from #Received
group by itemcode, parent 

---------------------------------------------------------------------------------------------------------
/*GET THE INITIAL ITEMS TO WORK ON*/
INSERT INTO CDC_SDV_WORK
	(VendorID,ReorderVendorID,ItemCode,Parent,ISBN,ProductType,SectionCode,Title,Cost,Price,MSRP,QtyShipped,AmtInvoiced,SchemeID,Reorderable,LastReceived,FirstReceived,FOBPO,FOBItem)
SELECT pm.VendorID,pm.PurchaseFromVendorID,pm.ItemCode, 'SHIP'[Parent],case ltrim(rtrim(pm.ISBN)) when '' then substring(pmd.upc,1,13) else pm.isbn end [ISBN],
	pm.ProductType,pm.SectionCode,CASE  pm.Title WHEN '' THEN pm.Description ELSE pm.Title END [Title], 
	pm.Cost,pm.Price,case when isnumeric(isnull(pm.MfgSuggestedPrice,0))=1 then isnull(pm.MfgSuggestedPrice,0) else 0 end,
	ship.shipQty,(pm.Cost * ISNULL(ship.shipQty,0)),pmd.SchemeID,pm.Reorderable,lastRcv.lastRcvd,lastRcv.firstRcvd,cast(o.FOBPO as varchar(250)),cast(o.FOBItem as varchar(250))
FROM ReportsData..ProductMaster pm with (nolock) JOIN ReportsData..ProductMasterDist PMD with (nolock) ON pmd.ItemCode=pm.ItemCode
	join (select distinct ItemCode, SUM(qtyshipped) [shipQty] from #ShipHist group by ItemCode) ship on ship.ItemCode = pm.ItemCode
	left join (select ItemCode,cast(min(firstRcvd) as smalldatetime)[firstRcvd],cast(max(LastRcvd) as smalldatetime)[lastRcvd] from #LastProcessedDate group by ItemCode) lastRcv on lastRcv.ItemCode = pm.ItemCode
	left join (select distinct oh.PONumber,od.ItemCode,cast(oh.SpecInstructions as varchar(250))[FOBPO],cast(od.SpecialInstructions as varchar(250))[FOBItem] from ReportsData..OrderHeader oh with(nolock) inner join ReportsData..OrderDetail od with(nolock) on oh.PONumber=od.PONumber
				where (ISNULL(oh.SpecInstructions,'')<>'' or ISNULL(od.SpecialInstructions,'')<>'')) o on o.ItemCode=pm.itemcode and o.PONumber=pm.LastPurchaseOrder
WHERE pm.ItemCode NOT IN (SELECT distinct NewItemCode FROM ReportsData..RecvDtlItemsCreated)
	AND pm.ItemCode NOT IN (SELECT distinct ItemCode FROM ReportsData..RecvDtlItemsCreated)
	AND (pm.CreateDate BETWEEN @i_StartDate AND @i_EndDate or pm.Reorderable='Y' or lastrcv.lastRcvd between @i_StartDate and @i_EndDate)
	
----CDC rcvd info
INSERT INTO CDC_SDV_WORK
	(VendorID,ReorderVendorID,ItemCode,Parent,ISBN,ProductType,SectionCode,Title,Cost,Price,MSRP,QtyShipped,AmtInvoiced,SchemeID,Reorderable,LastReceived,FirstReceived,FOBPO,FOBItem)
SELECT pm.VendorID,pm.PurchaseFromVendorID,pm.ItemCode,case when pm.Reorderable='Y'  then ' ' else 'RCVD'end[Parent],case ltrim(rtrim(pm.ISBN)) when '' then substring(pmd.upc,1,13) else pm.isbn end [ISBN],
	pm.ProductType,pm.SectionCode,CASE  pm.Title WHEN '' THEN pm.Description ELSE pm.Title END [Title], 
	pm.Cost,pm.Price,case when isnumeric(isnull(pm.MfgSuggestedPrice,0))=1 then isnull(pm.MfgSuggestedPrice,0) else 0 end,
	rcv.QtyRcvd,(pm.Cost * ISNULL(rcv.QtyRcvd,0)),pmd.SchemeID,pm.Reorderable,lastRcv.lastRcvd,lastRcv.firstRcvd,cast(o.FOBPO as varchar(250)),cast(o.FOBItem as varchar(250))
FROM ReportsData..ProductMaster pm with (nolock) JOIN ReportsData..ProductMasterDist PMD with (nolock) ON pmd.ItemCode=pm.ItemCode
	join #ILSRcvHist rcv on rcv.itemcode = pm.itemcode
	left join (select ItemCode,cast(min(firstRcvd) as smalldatetime)[firstRcvd],cast(max(LastRcvd) as smalldatetime)[lastRcvd] from #LastProcessedDate group by ItemCode) lastRcv on lastRcv.ItemCode = pm.ItemCode
	left join (select distinct oh.PONumber,od.ItemCode,cast(oh.SpecInstructions as varchar(250))[FOBPO],cast(od.SpecialInstructions as varchar(250))[FOBItem] from ReportsData..OrderHeader oh with(nolock) inner join ReportsData..OrderDetail od with(nolock) on oh.PONumber=od.PONumber
				where (ISNULL(oh.SpecInstructions,'')<>'' or ISNULL(od.SpecialInstructions,'')<>'')) o on o.ItemCode=pm.itemcode and o.PONumber=pm.LastPurchaseOrder
WHERE (pm.CreateDate BETWEEN @i_StartDate AND @i_EndDate or pm.Reorderable='Y' or lastrcv.lastRcvd between @i_StartDate and @i_EndDate) 

/*CAN ANY BASE INVENTORY*/
DELETE CDC_SDV_WORK WHERE ItemCode in (select ItemCode from ReportsData..BaseInventory with (nolock)) or SCHEMEID='BASE INVENTORY' or VendorID = 'WHPBSUPPLY' or ReorderVendorID='WHPBSUPPLY'

/*next 2 for transfers*/
--get non-damage transfers.....
UPDATE s
SET s.QtyTrans=isnull(it.QtyShipped,0)
FROM CDC_SDV_WORK s 
	join (SELECT SUM(ISNULL(sd.QTY,0))AS QtyShipped,sd.ItemCode
	FROM ReportsData..ShipmentDetail sd
	INNER JOIN ReportsData..ShipmentHeader sh on sh.transferid=sd.transferid
	WHERE sd.DateReceived BETWEEN @i_StartDate AND DATEADD(day,1,@i_EndDate) AND sh.DropShipment=0
	AND EXISTS ( SELECT ItemCode FROM ReportsData..InventoryTransfers WHERE FromLocationNo=sh.FromLocationNo and ToLocationNo=sh.ToLocationNo and TransferID=sh.TransferID and itemCode=sd.ItemCode)
		and sh.ToLocationNo<>'00300' --exclude transfers to damage.
	GROUP BY sd.ItemCode) it on it.ItemCode=s.ItemCode
--get damage transfers.....
UPDATE s
SET s.QtyDamaged=isnull(it.QtyShipped,0)
FROM CDC_SDV_WORK s 
	join (SELECT SUM(ISNULL(sd.QTY,0))AS QtyShipped,sd.ItemCode
	FROM ReportsData..ShipmentDetail sd
	INNER JOIN ReportsData..ShipmentHeader sh on sh.transferid=sd.transferid
	WHERE sd.DateReceived BETWEEN @i_StartDate AND DATEADD(day,1,@i_EndDate) AND sh.DropShipment=0
	AND EXISTS ( SELECT ItemCode FROM ReportsData..InventoryTransfers WHERE FromLocationNo=sh.FromLocationNo and ToLocationNo=sh.ToLocationNo and TransferID=sh.TransferID and itemCode=sd.ItemCode)
		and sh.ToLocationNo='00900' --get only damage transfers.
	GROUP BY sd.ItemCode) it on it.ItemCode=s.ItemCode

/*Next update dropship qty with store received qty*/
Update s
set s.QtyShipped =(select sum(x.Qty) from ((select isnull(SUM(Qty),0)[Qty] from ReportsData..SR_Detail where itemcode=s.itemcode)
					union 
					(select isnull(SUM(Qty),0)[Qty] from ReportsData..SR_Detail_Historical where itemcode=s.itemcode)) x)
from CDC_SDV_WORK s --join #Received r on s.ItemCode=r.itemcode
	join (select distinct ItemCode from #ShipHist where DropShip=1) ship on ship.ItemCode=s.ItemCode
where LTRIM(RTRIM(s.Parent)) in ('DS','SHIP')

/*Next update parent*/
UPDATE s
SET s.parent = case(pd.parent) when 'DS' then ' ' when 'SR' then ' ' when 'DR' then ' ' else s.Parent end,
	s.LastReceived=(select max(LastRcvd) from #LastProcessedDate where itemcode=s.ItemCode),s.FirstReceived=(select min(firstRcvd) from #LastProcessedDate where itemcode=s.ItemCode)
FROM CDC_SDV_WORK s JOIN #LastProcessedDate pd on pd.itemcode=s.itemcode

update CDC_SDV_WORK set parent = ' ' where lastreceived is null and (Reorderable = 'N' or QtyShipped = 0)
update CDC_SDV_WORK set parent = 'SRPR' where lastreceived is null and Reorderable = 'Y' and QtyShipped > 0
--update CDC_SDV_WORK set Parent = ' ' where Parent='RCVD' and ItemCode in (select distinct itemcode from #ShipHist)

drop table #ShipHist
drop table #ILSRcvHist
drop table #Received
drop table #LastProcessedDate

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CDC_SDV_ONHAND]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	DROP TABLE CDC_SDV_ONHAND

/*next 2 for on hand*/
SELECT SUM(isnull(pv.QuantityOnHand,0))[Qty],pv.ItemCode INTO CDC_SDV_ONHAND
from ReportsData..ProductInventory pv  with (nolock) join (select distinct itemcode from CDC_SDV_WORK) s on s.ItemCode = pv.ItemCode
GROUP BY pv.ItemCode

UPDATE CDC_SDV_WORK
SET OnHand=q.Qty 
FROM CDC_SDV_WORK s JOIN CDC_SDV_ONHAND q   on s.ItemCode=q.ItemCode

DROP TABLE CDC_SDV_ONHAND

UPDATE CDC_SDV_WORK SET QtyTrans=0 WHERE QtyTrans IS NULL
UPDATE CDC_SDV_WORK SET OnHand=0 WHERE OnHand IS NULL

----get UPC/ISBN items..................................................................
select pm.ItemCode,pmd.ReportItemCode
into #upcItems
from ReportsData..ProductMaster pm with (nolock) inner join ReportsData..ProductMasterDist pmd with (nolock)
	on pm.ItemCode=pmd.ItemCode
where pm.ItemCode in (select distinct right('00000000000000000000' + replace(ItemAlias,'UPC',''),20) from ReportsData..ProductMaster where ItemAlias like 'UPC%')

--------------------------------------------------------------------------------------------------------------------------------------
insert into CDC_SDV_SalesData
select sum(t.ExtendedAmt)[ExtendedAmt],sum(t.RegisterPrice)[RegisterPrice],sum(t.QtySold)[QtySold],sum(t.QtyReturned)[QtyReturned],sum(t.Coupons)[Coupons],sum(t.CouponAmt)[CouponAmt],
	sum(t.markeddown)[markeddown],sum(t.QtyDisc)[QtyDisc],sum(t.DiscAmt)[DiscAmt],t.ItemCode
from (
select cast(sum(case when sih.IsReturn='N' then sih.ExtendedAmt else 0 end)as money)[ExtendedAmt],
		cast(sum(case when sih.IsReturn='N' then sih.RegisterPrice else 0 end)as money)[RegisterPrice],
		sum(case when sih.IsReturn='N' then sih.Quantity else 0 end) [QtySold],
		sum(case when sih.IsReturn='Y' then sih.Quantity else 0 end) [QtyReturned],
		sum(case when sih.ODPCFlag='C' then sih.Quantity else 0 end) [Coupons],
		cast(sum(case when sih.ODPCFlag='C' then sih.DiscountAmt else 0 end)as money) [CouponAmt],
		sum(Case when sih.UnitPrice > sih.RegisterPrice THEN 1 ELSE 0 END) [markeddown],
		sum(case when sih.discountpct > 0 and sih.IsReturn='N' then 1 else 0 end) [QtyDisc],
		cast(sum(case when sih.DiscountAmt > 0 and sih.IsReturn='N' then sih.DiscountAmt else 0 end)as money) [DiscAmt],
		sih.ItemCode
FROM rHPB_Historical.dbo.SalesItemHistory sih with (nolock) 
	join (select distinct itemcode from CDC_SDV_WORK) s on s.ItemCode = sih.ItemCode
WHERE sih.XactionType='S' and sih.status='A' AND sih.BusinessDate >= @i_StartDate AND sih.BusinessDate <=@i_SalesEnding
	and sih.ItemCode not in (select distinct itemcode from #upcItems)
GROUP BY sih.ItemCode
union
select	cast(sum(case when sih.IsReturn='N' then sih.ExtendedAmt else 0 end)as money)[ExtendedAmt],
		cast(sum(case when sih.IsReturn='N' then sih.RegisterPrice else 0 end)as money)[RegisterPrice],
		sum(case when sih.IsReturn='N' then sih.Quantity else 0 end) [QtySold],
		sum(case when sih.IsReturn='Y' then sih.Quantity else 0 end) [QtyReturned],
		sum(case when sih.ODPCFlag='C' then sih.Quantity else 0 end) [Coupons],
		cast(sum(case when sih.ODPCFlag='C' then sih.DiscountAmt else 0 end)as money) [CouponAmt],
		sum(Case when sih.UnitPrice > sih.RegisterPrice THEN 1 ELSE 0 END) [markeddown],
		sum(case when sih.discountpct > 0 and sih.IsReturn='N' then 1 else 0 end) [QtyDisc],
		cast(sum(case when sih.DiscountAmt > 0 and sih.IsReturn='N' then sih.DiscountAmt else 0 end)as money) [DiscAmt],
		u.ReportItemCode
from rhpb_historical..SalesItemHistory sih with(nolock) inner join #upcItems u on sih.ItemCode=u.ItemCode
where sih.XactionType='S' and sih.Status = 'A' AND sih.BusinessDate >= @i_StartDate AND sih.BusinessDate <=@i_SalesEnding
group by u.ReportItemCode) t
group by t.ItemCode

update w 
set w.QtySold=s.QuantitySold,w.RegisterPrice=s.RegisterPrice,w.QtyReturned=s.Returned,w.ExtendedAmt=s.ExtendedAmt,w.Coupons=s.Coupons,w.CouponAmt=s.CouponAmt,w.QtyDisc=s.QtyDisc,w.DiscAmt=s.DiscAmt,w.QtyMarkedDown=s.MarkedDown
from CDC_SDV_WORK w inner join CDC_SDV_SalesData s on w.ItemCode=s.ItemCode


IF OBJECT_ID('tempdb..#online_sales') IS NOT NULL DROP TABLE #online_sales
	create table #online_sales
	(ItemCode nvarchar(25),	SellingPrice money , [OnlineQtySold] numeric(19),  DateSold datetime,	)

insert into #online_sales
select	 ItemCode, (cast(avg(SellingPrice)as money)) [ExtendedAmt],	sum(Quantity) [OnlineQtySold],max(DateSold)
from reportsdata..Sales_OnlineMarketPlaces_Distribution sod with(nolock) 
where sod.DateSold >= @i_StartDate AND sod.DateSold <=@i_SalesEnding
	and ItemCode not in (select distinct itemcode from #upcItems)
group by ItemCode
order by ItemCode

---------------------------------------------------------------------------------------------------------------------------------------

--/*Insert sales data for the work items*/
--INSERT INTO CDC_SDV_SALES
--SELECT SUM(sih.ExtendedAmt) AS ExtendedAmt, SUM(sih.RegisterPrice) AS RegisterPrice,SUM(sih.Quantity) AS QuantitySold, 
--sih.ItemCode
-- FROM rHPB_Historical.dbo.SalesItemHistory sih with (nolock)
--	join (select distinct itemcode from CDC_SDV_WORK) s on s.ItemCode = sih.ItemCode
--WHERE sih.XactionType='S' and sih.status='A' AND ISRETURN='N' AND sih.BusinessDate >= @i_StartDate AND sih.BusinessDate <=@i_SalesEnding
--GROUP BY sih.ItemCode

--/*now update the work table with the sales numbers*/
--UPDATE CDC_SDV_WORK
--SET QtySold=sih.QuantitySold,RegisterPrice=sih.RegisterPrice,ExtendedAmt=sih.ExtendedAmt
--FROM CDC_SDV_WORK s JOIN CDC_SDV_SALES sih on sih.itemcode=s.itemcode
--DROP TABLE CDC_SDV_SALES

--/*DO THE RETURNS THING JUST LIKE SALES*/
--INSERT INTO CDC_SDV_RETURNS
--SELECT SUM(sih.Quantity) AS Returned,sih.ItemCode
--FROM rHPB_Historical.dbo.SalesItemHistory sih with (nolock) 
--	join (select distinct itemcode from CDC_SDV_WORK) s on s.ItemCode = sih.ItemCode
--WHERE sih.XactionType='S' and sih.status='A' AND ISRETURN='Y' AND sih.BusinessDate >= @i_StartDate AND sih.BusinessDate <=@i_SalesEnding
--GROUP BY sih.ItemCode

--/*UPDATE THE WORK TABLE WITH THE RETURNS NUMBERS*/
--UPDATE CDC_SDV_WORK
--SET QtyReturned=srh.Returned
--FROM CDC_SDV_WORK s JOIN CDC_SDV_RETURNS srh on srh.itemcode=s.itemcode
--DROP TABLE CDC_SDV_RETURNS

/*dump in the Pending stuff*/
----first get pending TTB items that have been reorded..............
/*Get TTB reorded items........................................................................................................*/
create table #TBRIitems (itemcode char(20))
CREATE  CLUSTERED  INDEX [IDX_items] ON #TBRIitems ( [ItemCode])
insert into #TBRIitems
select distinct od.ItemCode
from ReportsData..OrderDetail od with(nolock) inner join ReportsData..OrderHeader oh with(nolock) on od.PONumber=oh.PONumber
	inner join ReportsData..CDC_TradeShowRollUpNew tsr with(nolock) on tsr.ItemCode=od.ItemCode
	inner join ReportsData..ProductMaster pm with(nolock) on od.ItemCode=pm.ItemCode
where pm.UserChar15='TTB' and oh.LocationNo='00944' and isnull(oh.SkeletonCreatedFrom,'')='' and oh.CreatedFromRequisition=0 and oh.CancelDate is null

/*Received POs........................................................................................................*/
create table #TBRIReceived (itemcode char(20), ponumber char(6))
CREATE  CLUSTERED  INDEX [IDX_items] ON #TBRIReceived ( [ItemCode])
----run archive table first for CDC shipments to get min dates for items.......................................
insert into #TBRIReceived --archive SR tables / CDC shipments....
	select distinct sd.itemcode [ItemCode],right(sh.ShipmentNo,6) [PONumber]
	from ReportsData..SR_Header_Historical sh with (nolock) inner join ReportsData..SR_Detail_Historical sd with (nolock) on sh.BatchID = sd.BatchID
		inner join #TBRIitems i on sd.ItemCode=i.itemcode inner join ReportsData..OrderHeader oh with(nolock) on oh.PONumber=right(sh.ShipmentNo,6)
	where sh.ShipmentType in ('W','R')  
insert into #TBRIReceived --current SR tables / CDC shipments....
	select distinct sd.itemcode [ItemCode],right(sh.ShipmentNo,6) [PONumber]
	from ReportsData..SR_Header sh with (nolock) inner join ReportsData..SR_Detail sd with (nolock) on sh.BatchID = sd.BatchID
		inner join #TBRIitems i on sd.ItemCode=i.itemcode inner join ReportsData..OrderHeader oh with(nolock) on oh.PONumber=right(sh.ShipmentNo,6)
	where sh.ShipmentType in ('W','R') 
insert into #TBRIReceived --get WMS recevied.....
	select distinct right('00000000000000000000' + item, 20)[ItemCode],
	case when isnumeric(PURCHASE_ORDER_ID)=1 then PURCHASE_ORDER_ID else LEFT(PURCHASE_ORDER_ID,6)end [PONumber]
	from rILS_data..RECEIPT_DETAIL inner join #TBRIitems i on right('00000000000000000000' + item, 20)=i.itemcode 
	where PURCHASE_ORDER_ID is not null
insert into #TBRIReceived --get WMS archived recevied.....
	select distinct right('00000000000000000000' + item, 20)[ItemCode],
	case when isnumeric(PURCHASE_ORDER_ID)=1 then PURCHASE_ORDER_ID else LEFT(PURCHASE_ORDER_ID,6)end [PONumber]
	from rILS_data..AR_RECEIPT_DETAIL inner join #TBRIitems i on right('00000000000000000000' + item, 20)=i.itemcode 
	where PURCHASE_ORDER_ID is not null

----get final results......................................................................................................................................
INSERT INTO CDC_SDV_PENDING
	(FirstReceived,LastReceived,LastPO,VendorID,ReorderVendorID,ItemCode,Parent,ISBN,ProductType,Buyer,SectionCode,Title,Cost,Price,MSRP,QtyShipped,AmtInvoiced,SchemeID,Reorderable,FOBPO,FOBItem)
SELECT oh.PODate,oh.PODate,od.PONumber,pm.VendorID,pm.PurchaseFromVendorID,
	pm.ItemCode,'TBRI'[Parent],case ltrim(rtrim(pm.ISBN)) when '' then substring(pmd.upc,1,13) else pm.isbn end [ISBN],
	pm.ProductType,oh.BuyerID,pm.SectionCode,CASE  pm.Title WHEN '' THEN pm.Description ELSE pm.Title END [Title], 
	pm.Cost,pm.Price,case when isnumeric(isnull(pm.MfgSuggestedPrice,0))=1 then isnull(pm.MfgSuggestedPrice,0) else 0 end [MSRP],
	od.OrderQty,(pm.Cost * ISNULL(od.OrderQty,0))[AmtInvoiced],od.SchemeID,pm.Reorderable,cast(oh.SpecInstructions as varchar(250))[FOBPO],cast(od.SpecialInstructions as varchar(250))[FOBItem]
from ReportsData..OrderHeader oh with(nolock) inner join ReportsData..OrderDetail od with(nolock) on oh.PONumber=od.PONumber
	inner join #TBRIitems i on i.itemcode=od.ItemCode inner join ReportsData..ProductMaster pm with(nolock) on i.itemcode=pm.ItemCode
	inner join ReportsData..ProductMasterDist pmd with(nolock) on pmd.ItemCode=pm.ItemCode
	left outer join (select distinct itemcode,PONumber from #TBRIReceived) r on r.itemcode=i.itemcode and oh.PONumber=r.ponumber
where oh.LocationNo='00944' and oh.CreatedFromRequisition=0 and r.itemcode is null
	and isnull(oh.PODate,GETDATE())>DATEADD(year,-1,getdate()) and oh.CancelDate is null

----now get all other pending items excluded those in the previous step......................................................................................
INSERT INTO CDC_SDV_PENDING
	(FirstReceived,LastReceived,LastPO,VendorID,ReorderVendorID,ItemCode,Parent,ISBN,ProductType,Buyer,SectionCode,Title,Cost,Price,MSRP,QtyShipped,AmtInvoiced,SchemeID,Reorderable,FOBPO,FOBItem)
SELECT oh.PODate,oh.PODate,od.PONumber,pm.VendorID,pm.PurchaseFromVendorID,
	pm.ItemCode,'PEND'[Parent],case ltrim(rtrim(pm.ISBN)) when '' then substring(pmd.upc,1,13) else pm.isbn end [ISBN],
	pm.ProductType,oh.BuyerID,pm.SectionCode,CASE  pm.Title WHEN '' THEN pm.Description ELSE pm.Title END [Title], 
	pm.Cost,pm.Price,case when isnumeric(isnull(pm.MfgSuggestedPrice,0))=1 then isnull(pm.MfgSuggestedPrice,0) else 0 end,
	od.OrderQty,(pm.Cost * ISNULL(od.OrderQty,0)),od.SchemeID,pm.Reorderable,cast(oh.SpecInstructions as varchar(250))[FOBPO],cast(od.SpecialInstructions as varchar(250))[FOBItem]
FROM ReportsData..ProductMaster pm with (nolock) JOIN ReportsData..ProductMasterDist PMD with (nolock) ON pmd.ItemCode=pm.ItemCode
	JOIN ReportsData..OrderDetail od with (nolock) ON od.ItemCode=pm.ItemCode --AND od.PONumber=pm.LastPurchaseOrder
	JOIN ReportsData..OrderHeader oh with (nolock) ON oh.PONumber=od.PONumber
WHERE  od.DistributionType!='A' and isnull(oh.POType,'') not in ('S','C') AND oh.PODate > DATEADD(MONTH, -12,GETDATE()) and oh.CancelDate is null
	AND not exists (SELECT * FROM ReportsData..ShipmentDetail sd with (nolock) join ReportsData..ShipmentHeader sh with (nolock) on sh.TransferID=sd.TransferID	WHERE  sd.ItemCode=od.ItemCode)
	AND not EXISTS (SELECT * FROM CDC_SDV_WORK WHERE ItemCode=pm.ItemCode) AND not EXISTS (SELECT * FROM CDC_SDV_PENDING WHERE ItemCode=pm.ItemCode)

/*INSERT WHATEVER PENDING IS LEFT TO THE WORK TABLE*/
INSERT INTO CDC_SDV_WORK
	(VendorID, ReorderVendorID, ItemCode, Parent, ISBN, ProductType, Buyer, SectionCode, Title, Cost, Price, MSRP, QtyShipped, QtyTrans, QtyDamaged, QtySold, QtyReturned, RegisterPrice, ExtendedAmt, OnHand, AmtInvoiced, Reorderable, LastPO, LastReceived, FirstReceived, SchemeID)
SELECT VendorID, ReorderVendorID, ItemCode, Parent, ISBN, ProductType, Buyer, SectionCode, Title, Cost, Price, MSRP, QtyShipped, QtyTrans, QtyDamaged, QtySold, QtyReturned, RegisterPrice, ExtendedAmt, OnHand, AmtInvoiced, Reorderable, LastPO, LastReceived, FirstReceived, SchemeID FROM CDC_SDV_PENDING

/*CAN THE TEMP POs TABLE IN CASE SOMETHING HAPPENED LAST RUN...*/
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CDC_SDV_POs]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	DROP TABLE CDC_SDV_POs

/*BUILD TEMP TABLE WITH PO RELATED INFO*/
--LastPO
SELECT MAX(sd.PONumber)[PONumber],sd.ItemCode,CAST(''as varchar(250))[FOBPO],CAST(''as varchar(250))[FOBItem]
INTO #tmpPOs
FROM CDC_SDV_WORK s JOIN ReportsData..ShipmentDetail sd with (nolock) on sd.itemcode=s.itemcode
where sd.PONumber not in (select distinct LastPO from CDC_SDV_PENDING)
GROUP BY sd.ItemCode

INSERT INTO #tmpPOs
SELECT MAX(sd.PONumber)[PONumber],sd.ItemCode,cast(oh.SpecInstructions as varchar(250))[FOBPO],cast(sd.SpecialInstructions as varchar(250))[FOBItem]
FROM CDC_SDV_WORK s JOIN ReportsData..OrderDetail sd with (nolock) on sd.itemcode=s.itemcode
	inner join ReportsData..OrderHeader oh with(nolock) on sd.PONumber=oh.PONumber
where sd.PONumber not in (select distinct ponumber from #tmpPOs where ItemCode=sd.ItemCode) and sd.PONumber not in (select distinct p.LastPO from CDC_SDV_PENDING p)
	and isnull(oh.SkeletonCreatedFrom,'')='' and oh.CreatedFromRequisition=0 and oh.CancelDate is null
GROUP BY sd.ItemCode,oh.SpecInstructions,sd.SpecialInstructions

SELECT MAX(s.PONumber)[PONumber],s.ItemCode,s.FOBPO,s.FOBItem INTO CDC_SDV_POs
FROM #tmpPOs s 
GROUP BY s.ItemCode,s.FOBPO,s.FOBItem

/*UPDATE THE WORK TABLE WITH LAST PO*/
UPDATE CDC_SDV_WORK
SET FOBPO=s.FOBPO,FOBItem=s.FOBItem
FROM CDC_SDV_WORK s JOIN CDC_SDV_POs sd on sd.itemcode=s.itemcode

UPDATE t
set t.FOBItem=cast(od.SpecialInstructions as varchar(250)),t.FOBPO=cast(oh.SpecInstructions as varchar(250))
from CDC_SDV_WORK t inner join ReportsData..OrderDetail od on od.ItemCode=t.ItemCode and od.PONumber=t.LastPO	
		inner join ReportsData..OrderHeader oh on t.LastPO=oh.PONumber	
where ISNULL(t.FOBItem,'')='' and isnull(od.SpecialInstructions,'')<>''

UPDATE t
set t.FOBItem=cast(od.SpecialInstructions as varchar(250)),t.FOBPO=cast(oh.SpecInstructions as varchar(250))
from CDC_SDV_WORK t inner join ReportsData..OrderDetail od on od.ItemCode=t.ItemCode and od.PONumber=t.LastPO	
		inner join ReportsData..OrderHeader oh on t.LastPO=oh.PONumber	
where ISNULL(t.FOBPO,'')='' and isnull(oh.SpecInstructions,'')<>''

UPDATE CDC_SDV_WORK
SET LastPO=sd.PONumber
FROM CDC_SDV_WORK s JOIN CDC_SDV_POs sd on sd.itemcode=s.itemcode
where Parent<>'TBRI'
DROP TABLE CDC_SDV_POs

-- get last PO# from ProdMaster for Assortment Items.... 10/22/2010 JoeyB
update CDC_SDV_WORK
set LastPO = pm.lastpurchaseorder
from CDC_SDV_WORK s join ReportsData..ProductMaster pm with (nolock) on pm.ItemCode = s.ItemCode
where RIGHT(pm.ItemCode,8) > '19999999'	or s.LastPO is null

----get publisher/author.....
update c
set c.Publisher=left(i.PublisherName,250),c.Author=left(i.Author,250)
from CDC_SDV_WORK c inner join ReportsData..ISBN13 i on i.ISBN=c.ISBN

/*CAN THE PENDING TABLE*/
DROP TABLE CDC_SDV_PENDING
drop table #TBRIitems
drop table #TBRIReceived

/*ADD BUYERS NAME*/----changed the buyer section to get original buyer instead of buy associated with LastPO.... JoeyB. 4/1/2015
select oh.PONumber,od.ItemCode,cast(' 'as varchar(30))[Buyer],min(oh.PODate)[PODate]
into #BuyerPO
from ReportsData..OrderHeader oh inner join ReportsData..OrderDetail od on oh.PONumber=od.PONumber
	inner join CDC_SDV_WORK csw on csw.ItemCode=od.ItemCode
group by oh.PONumber,od.ItemCode

update bp
set bp.Buyer=b.[Name]
from #BuyerPO bp inner join ReportsData..OrderHeader oh with (nolock) on bp.PONumber=oh.PONumber and bp.PODate=oh.PODate
	inner join ReportsData..Buyers b with (nolock) on b.BuyerID=oh.BuyerID
	
UPDATE CDC_SDV_WORK
SET Buyer=bp.Buyer
FROM CDC_SDV_WORK s inner join #BuyerPO bp on s.ItemCode=bp.ItemCode
	
UPDATE s
SET s.Buyer=b.Name
FROM CDC_SDV_WORK s inner join ReportsData..OrderHeader oh on s.LastPO=oh.PONumber
	inner join ReportsData..Buyers b on oh.BuyerID=b.BuyerID
where ltrim(rtrim(ISNULL(s.Buyer,'')))=''

-- Added the below update statement to update sectioncodes instead of doing a join.... 10/22/2010 JoeyB....
update CDC_SDV_WORK 
set SectionCode = UPPER(ISNULL(smd.SectionCode, 'NONE'))
from CDC_SDV_WORK cdc join reportsdata..SectionMasterForDIPS smd with (nolock) on smd.ItemCode = cdc.ItemCode

/*DO SOME HOUSE CLEANING...*/
DELETE from CDC_SDV_WORK where VendorID = 'WHPBSUPPLY' or ReorderVendorID = 'WHPBSUPPLY' or SchemeID='ECOM' 
UPDATE CDC_SDV_WORK SET QtyReturned=0 WHERE QtyReturned IS NULL
UPDATE CDC_SDV_WORK SET QtySold=0 WHERE QtySold IS NULL
UPDATE CDC_SDV_WORK SET RegisterPrice=0 WHERE RegisterPrice IS NULL
UPDATE CDC_SDV_WORK SET ExtendedAmt=0 WHERE ExtendedAmt IS NULL
UPDATE CDC_SDV_WORK SET QtyTrans=0 WHERE QtyTrans IS NULL
UPDATE CDC_SDV_WORK SET OnHand=0 WHERE OnHand IS NULL
UPDATE CDC_SDV_WORK SET Parent='' WHERE Parent IS NULL
UPDATE CDC_SDV_WORK SET Buyer='' WHERE Buyer IS NULL
UPDATE CDC_SDV_WORK SET AmtInvoiced = 0 WHERE ISNULL(LastPO,'')=''
UPDATE CDC_SDV_WORK SET QtyDisc=0 WHERE QtyDisc IS NULL
UPDATE CDC_SDV_WORK SET DiscAmt=0 WHERE DiscAmt IS NULL
UPDATE CDC_SDV_WORK SET Coupons=0 WHERE Coupons IS NULL
UPDATE CDC_SDV_WORK SET CouponAmt=0 WHERE CouponAmt IS NULL
UPDATE CDC_SDV_WORK SET QtyDamaged=0 WHERE QtyDamaged IS NULL
UPDATE CDC_SDV_WORK SET QtyMarkedDown=0 WHERE QtyMarkedDown IS NULL


----update UPC/ISBN items to their parent itemcode..........
update t
set t.itemcode=u.reportitemcode, t.Reorderable=(select top 1 Reorderable from CDC_SDV_WORK where ItemCode=u.reportitemcode),t.QtyShipped=0,
	t.VendorID=(select top 1 pm.vendorid from ReportsData..ProductMaster pm where pm.ItemCode=u.reportitemcode),
	t.ReorderVendorID=(select top 1 pm.PurchaseFromVendorID from ReportsData..ProductMaster pm where pm.ItemCode=u.reportitemcode),
	t.Parent=(select top 1 Parent from CDC_SDV_WORK where ItemCode=u.reportitemcode),
	t.SchemeID=(select top 1 SchemeID from CDC_SDV_WORK where ItemCode=u.reportitemcode),
	t.LastReceived=(select top 1 LastReceived from CDC_SDV_WORK where ItemCode=u.reportitemcode),
	t.FirstReceived=(select top 1 FirstReceived from CDC_SDV_WORK where ItemCode=u.reportitemcode),
	t.Buyer=(select top 1 Buyer from CDC_SDV_WORK where ItemCode=u.reportitemcode),
	t.LastPO=(select top 1 LastPO from CDC_SDV_WORK where ItemCode=u.reportitemcode),
	t.ISBN=(select top 1 ISBN from CDC_SDV_WORK where ItemCode=u.reportitemcode),
	t.AmtInvoiced=0
from CDC_SDV_WORK t inner join #upcitems u on t.itemcode=u.itemcode

select distinct VendorID, ReorderVendorID, ItemCode, Parent, ISBN, ProductType, 
	Buyer, SectionCode, Title, Cost, Price, MSRP, sum(isnull(QtyShipped,0))[QtyShipped], sum(isnull(QtyTrans,0))[QtyTrans], 
	sum(isnull(QtyDamaged,0))[QtyDamaged], sum(isnull(QtySold,0))[QtySold],sum(isnull(QtyMarkedDown,0))[QtyMarkedDown],sum(isnull(QtyReturned,0))[QtyReturned], 
	sum(isnull(RegisterPrice,0))[RegisterPrice], sum(isnull(ExtendedAmt,0))[ExtendedAmt], sum(isnull(OnHand,0))[OnHand], sum(isnull(AmtInvoiced,0))[AmtInvoiced], 
	Reorderable, max(LastPO)[LastPO], max(LastReceived)[LastReceived], min(FirstReceived)[FirstReceived], max(SchemeID)[SchemeID],
	max(FOBPO)[FOBPO],max(FOBItem)[FOBItem],max(Publisher)[Publisher],max(Author)[Author],sum(isnull(Coupons,0))[Coupons],
	sum(isnull(CouponAmt,0))[CouponAmt],sum(isnull(QtyDisc,0))[QtyDisc],sum(isnull(DiscAmt,0))[DiscAmt]
into #CDC_TradeShowRollUp
from CDC_SDV_WORK
where ItemCode not in (select ItemCode from #upcItems) and Parent<>'TBRI'
group by VendorID,ReorderVendorID,ItemCode,Parent,ISBN,ProductType,Buyer,SectionCode,Title,Cost,Price,MSRP,Reorderable 

insert into #CDC_TradeShowRollUp
select VendorID,ReorderVendorID,ItemCode,Parent,ISBN,ProductType,Buyer,SectionCode,Title,Cost,Price,MSRP,QtyShipped,QtyTrans,QtyDamaged,QtySold,QtyMarkedDown,QtyReturned,RegisterPrice,ExtendedAmt,
	OnHand,AmtInvoiced,Reorderable,LastPO,LastReceived,FirstReceived,SchemeID,FOBPO,FOBItem,Publisher,Author,Coupons,CouponAmt,QtyDisc,DiscAmt
from CDC_SDV_WORK
where Parent='TBRI'

----update results with any BT returns....
select it.ItemCode,sum(it.TransferQty)[TotalReturns]
into #BSRtn
from ReportsData..InventoryTransfers it with(nolock) inner join #CDC_TradeShowRollUp ru on it.ItemCode=ru.ItemCode
where it.ToLocationNo='00300'
group by it.ItemCode

delete from #CDC_TradeShowRollUp where VendorID='WHPBSUPPLY' or ReorderVendorID = 'WHPBSUPPLY'

----get Wholesale values......
select g.ITEMNMBR,sum(isnull(g.QUANTITY,0))[QUANTITY],cast(sum(isnull(g.XTNDPRCE,0))as money)[XTNDPRCE]  
into #TXB
from (select sop.ITEMNMBR,(sop.QTYTOINV)[QUANTITY],(sop.XTNDPRCE)[XTNDPRCE]
	from ReportsData..TB_SOP10100 soph inner join reportsdata..TB_SOP10200 sop on soph.SOPNUMBE=sop.SOPNUMBE
		inner join (select distinct ItemCode from #CDC_TradeShowRollUp) c on c.ItemCode=right('00000000000000000000'+ltrim(rtrim(sop.ITEMNMBR)),20)
	where soph.SOPTYPE=3 and soph.CUSTNMBR not in ('SAMPLE','REPS') and soph.DOCID='STD' and soph.BCHSOURC !='Sales Void'
		and soph.CUSTNMBR not like 'MRDC%' and soph.CUSTNMBR not like 'RDC%' and soph.CUSTNMBR not like 'TTB%'
	group by sop.ITEMNMBR,sop.QTYTOINV,sop.XTNDPRCE
	union
	select sop.ITEMNMBR,(sop.QTYTOINV)[QUANTITY],(sop.XTNDPRCE)[XTNDPRCE] 
	from ReportsData..TB_SOP30200 soph inner join ReportsData..TB_SOP30300 sop on soph.SOPNUMBE=sop.SOPNUMBE
		inner join (select distinct ItemCode from #CDC_TradeShowRollUp) c on c.ItemCode=right('00000000000000000000'+ltrim(rtrim(sop.ITEMNMBR)),20)
	where soph.SOPTYPE=3 and soph.CUSTNMBR not in ('SAMPLE','REPS') and soph.DOCID='STD' and soph.BCHSOURC !='Sales Void'
		and soph.CUSTNMBR not like 'MRDC%' and soph.CUSTNMBR not like 'RDC%' and soph.CUSTNMBR not like 'TTB%'
	group by sop.ITEMNMBR,sop.QTYTOINV,sop.XTNDPRCE) g
group by g.ITEMNMBR

------reset status if out of stock....
update tsr
set tsr.Parent=''
from #CDC_TradeShowRollUp tsr
where tsr.Parent='RCVD' and (tsr.ItemCode in (select distinct right('00000000000000000000'+item,20)[Item] from ReportsData..CDC_OOS_ItemLog
											where right('00000000000000000000'+item,20) not in (select ItemCode from rILS_DATA..WMSAvailableQty))
							or tsr.ItemCode in (select distinct right('00000000000000000000'+ltrim(rtrim(ITEMNMBR)),20) from #TXB where cast(isnull(QUANTITY,0)as int)>0))




--clear the table for insert.....................................................................................................................................
truncate table ReportsData..CDC_TradeShowRollUpNEW

------/*INSERT THE WORK TABLE DATA AS THE LATEST COPY...*/
INSERT INTO ReportsData..CDC_TradeShowRollUpNEW
	(VendorID, ReorderVendorID, ItemCode, Parent, ISBN, ProductType, Buyer, SectionCode, Title, Cost, Price, MSRP, QtyShipped, QtyTrans, QtyDamaged, QtySold, QtyMarkedDown, QtyReturned, QtyRTV, RegisterPrice, ExtendedAmt, OnHand, AmtInvoiced, Reorderable, LastPO, LastReceived, FirstReceived, SchemeID,FOBPO,FOBItem,Publisher,Author,Coupons,CouponAmt,QtyDisc,DiscAmt,TXBQty,TXBAmt
	, OnlineQtySold, SellingPrice
	)
SELECT VendorID, ReorderVendorID, tsr.ItemCode, Parent, ISBN, ProductType, Buyer, SectionCode, Title, Cost, Price, MSRP, QtyShipped, QtyTrans, QtyDamaged, QtySold, QtyMarkedDown, QtyReturned, isnull(br.TotalReturns,0)[TotalReturns], RegisterPrice, ExtendedAmt, OnHand, AmtInvoiced, Reorderable, LastPO, LastReceived, FirstReceived, SchemeID, FOBPO, FOBItem, Publisher, Author
	,Coupons,CouponAmt,QtyDisc,DiscAmt,cast(isnull(txb.QUANTITY,0)as int)[TXBQty],cast(isnull(txb.XTNDPRCE,0)as money)[TXBAmt]
	, os.OnlineQtySold, os.SellingPrice
FROM #CDC_TradeShowRollUp tsr left outer join #BSRtn br on tsr.ItemCode=br.ItemCode
	 left outer join #TXB txb on right('00000000000000000000'+ltrim(rtrim(txb.ITEMNMBR)),20)=tsr.ItemCode
	 left outer join #online_sales os on tsr.ItemCode=os.ItemCode

	 
--------go back and update any missing FOBItems......
if (select COUNT(*) from ReportsData..CDC_TradeShowRollUpNEW t inner join ReportsData..OrderDetail od on od.ItemCode=t.ItemCode and od.PONumber=t.LastPO	
		where ISNULL(t.FOBItem,'')='' and isnull(od.SpecialInstructions,'')<>'')>0
	begin
		UPDATE t
		set t.FOBItem=cast(od.SpecialInstructions as varchar(250))
		from ReportsData..CDC_TradeShowRollUpNEW t inner join ReportsData..OrderDetail od on od.ItemCode=t.ItemCode and od.PONumber=t.LastPO
			inner join ReportsData..OrderHeader oh on t.LastPO=oh.PONumber	
		where ISNULL(t.FOBItem,'')='' and isnull(od.SpecialInstructions,'')<>''
	end
if (select COUNT(*) from ReportsData..CDC_TradeShowRollUpNEW t inner join ReportsData..OrderHeader oh on t.LastPO=oh.PONumber		
		where ISNULL(t.FOBPO,'')='' and isnull(oh.SpecInstructions,'')<>'')>0
	begin
		UPDATE t
		set t.FOBPO=cast(oh.SpecInstructions as varchar(250))
		from ReportsData..CDC_TradeShowRollUpNEW t inner join ReportsData..OrderHeader oh on t.LastPO=oh.PONumber		
		where ISNULL(t.FOBPO,'')='' and isnull(oh.SpecInstructions,'')<>''
	end

/*FINAL CLEANOUT*/
DROP TABLE CDC_SDV_WORK
Drop table CDC_SDV_SalesData
drop table #CDC_TradeShowRollUp
drop table #upcItems
drop table #tmpPOs
drop table #BuyerPO
drop table #BSRtn
drop table #TXB
drop table #online_sales

/*LATER*/
--RETURN

----------------------------------------------------------------------------------------------------------------------
GO
