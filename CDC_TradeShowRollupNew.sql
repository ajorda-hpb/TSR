-- SP: CDC_TradeShowRollUpNew
set ANSI_NULLS on
go
set QUOTED_IDENTIFIER off
go

create procedure [dbo].[CDC_TradeShowRollUpNew](
	@StartDate	 datetime='1/1/2008'
) as
/*	ChangeLog:
	2/15/2012 : Added MSRP to results for TSR. : Joey B. 
	8/13/2012 : Made change to include dropship items : Joey B.
	11/9/2016 : Made changes to include coupons, discounts, & TXB : Joey B.
	2/21/2018 : Added Online Quantity and Selling Price: Trey G.
*/

----------testing
--declare @StartDate datetime
--set @StartDate = '1/1/2008'

declare @i_StartDate 		datetime--purchases start date
declare @i_EndDate 			datetime--purchases end date
declare @i_SalesEnding 		datetime--sales thru
declare @i_ReportType 		int
--assortments=1, titles=2

select
	@i_StartDate=@StartDate
	,@i_EndDate=CAST(convert(varchar,GetDate(),101)as datetime)
	,@i_SalesEnding=CAST(convert(varchar,GetDate(),101)as datetime)


/*CREATE TABLES & INDEXES TO DO THE WORK*/
if exists (select * from dbo.sysobjects
			where id = object_id(N'[dbo].[CDC_SDV_PENDING]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table CDC_SDV_PENDING

create table CDC_SDV_PENDING(
	 [VendorID]        [varchar] (10)  not null 
	,[ReorderVendorID] [varchar] (10)  not null 
	,[ItemCode]        [varchar] (20)  not null 
	,[Parent]          [varchar] (8)   null 
	,[ISBN]            [varchar] (13)  null 
	,[ProductType]     [varchar](20)   null
	,[Buyer]           [varchar](50)   null
	,[SectionCode]     [varchar](10)   null
	,[Title]           [varchar] (70)  null 
	,[Cost]            [money]         null 
	,[Price]           [money]         null 
	,[MSRP]            [money]         null 
	,[QtyShipped]      [int]           null 
	,[QtyTrans]        [int]           null 
	,[QtyDamaged]      [int]           null
	,[QtySold]         [int]           null 
	,[QtyReturned]     [int]           null 
	,[RegisterPrice]   [money]         null 
	,[ExtendedAmt]     [money]         null 
	,[OnHand]          [int]           null 
	,[AmtInvoiced]     [money]         null 
	,[Reorderable]     [char](1)       null
	,[LastPO]          [char] (6)      null 
	,[LastReceived]    [smalldatetime] null 
	,[FirstReceived]   [smalldatetime] null 
	,[SchemeID]        [varchar] (20)  null
	,[TTBInv]          [int]           null
	,[FOBItem]         [varchar] (250) null
	,[FOBPO]           [varchar] (250) null
	,[Publisher]       [varchar] (250) null
	,[Author]          [varchar] (250) null
)

create  clustered  index [IDX_TEMP_PENDING] on CDC_SDV_PENDING ([VendorID], [ItemCode])


if exists (select * from dbo.sysobjects
			where id = object_id(N'[dbo].[CDC_SDV_WORK]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table CDC_SDV_WORK

create table CDC_SDV_WORK(
	 [VendorID]        [varchar] (10)  not null 
	,[ReorderVendorID] [varchar] (10)  not null 
	,[ItemCode]        [varchar] (20)  not null 
	,[Parent]          [varchar] (8)   null 
	,[ISBN]            [varchar] (13)  null 
	,[ProductType]     [varchar](20)   null
	,[Buyer]           [varchar](50)   null
	,[SectionCode]     [varchar](10)   null
	,[Title]           [varchar] (70)  null 
	,[Cost]            [money]         null 
	,[Price]           [money]         null 
	,[MSRP]            [money]         null 
	,[QtyShipped]      [int]           null 
	,[QtyTrans]        [int]           null 
	,[QtyDamaged]      [int]           null
	,[QtySold]         [int]           null 
	,[QtyReturned]     [int]           null 
	,[QtyMarkedDown]   [int]           null 
	,[RegisterPrice]   [money]         null 
	,[ExtendedAmt]     [money]         null 
	,[OnHand]          [int]           null 
	,[AmtInvoiced]     [money]         null 
	,[Reorderable]     [char](1)       null
	,[LastPO]          [char] (6)      null 
	,[LastReceived]    [smalldatetime] null 
	,[FirstReceived]   [smalldatetime] null 
	,[PctSold] as (case ISNULL(QtyShipped,0) when 0 then ISNULL(QtySold,0)else (convert(float,[QtySold]) / convert(float,[QtyShipped]) * 100)end) 
	,[SchemeID]        [varchar] (20)  null
	,[TTBInv]          [int]           null
	,[FOBItem]         [varchar] (250) null
	,[FOBPO]           [varchar] (250) null
	,[Publisher]       [varchar] (250) null
	,[Author]          [varchar] (250) null
	,[Coupons]         [int]           null 
	,[CouponAmt]       [money]         null 
	,[QtyDisc]         [int]           null 
	,[DiscAmt]         [money]         null
)

create  clustered  index [IDX_TEMP_PIG] on CDC_SDV_WORK ([VendorID], [ItemCode])


if exists (select * from dbo.sysobjects
			where id = object_id(N'[dbo].[CDC_SDV_SALES]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table CDC_SDV_SALES

create table CDC_SDV_SALES(
	ExtendedAmt   money
	,RegisterPrice money
	,QuantitySold  int
	,ItemCode      varchar(20)
)
create  clustered  index [IDX_PIG_SALES] on CDC_SDV_SALES( [ItemCode])


if exists (select * from dbo.sysobjects
			where id = object_id(N'[dbo].[CDC_SDV_SalesData]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table CDC_SDV_SalesData

create table CDC_SDV_SalesData(
	ExtendedAmt   money
	,RegisterPrice money
	,QuantitySold  int
	,Returned      int
	,Coupons       int
	,CouponAmt     money
	,MarkedDown    int
	,QtyDisc       int
	,DiscAmt       money
	,ItemCode      varchar(20)
)
create  clustered  index [IDX_PIG_SalesData] on CDC_SDV_SalesData( [ItemCode])


if exists (select * from dbo.sysobjects
			where id = object_id(N'[dbo].[CDC_SDV_RETURNS]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table CDC_SDV_RETURNS

create table CDC_SDV_RETURNS(
	Returned int
	,ItemCode varchar(20)
)
create  clustered  index [IDX_PIG_RETS] on CDC_SDV_RETURNS ( [ItemCode])


--create temp table to hold shipment history instead of using table function.  this cuts the runtime from 30 min to 5.....
if exists (select * from dbo.sysobjects
			where id = object_id(N'[dbo].[#ShipHist]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table #ShipHist
if exists (select * from dbo.sysobjects
			where id = object_id(N'[dbo].[#ILSRcvHist]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table #ILSRcvHist

create table #ShipHist(
	QtyShipped int
	,ItemCode   char(20)
	,DropShip   int
)
create  clustered  index [IDX_items] on #ShipHist ( [ItemCode])

create table #ILSRcvHist(
	QtyRcvd  int
	,ItemCode char(20)
)
create  clustered  index [IDX_items] on #ILSRcvHist ( [ItemCode])



insert into #ShipHist
select
	SUM(ISNULL(sd.QTY,0)) as QtyShipped
	,sd.ItemCode
	,case when (sh.dropshipment)= 0 then 0 else 1 end
from ReportsData..ShipmentDetail sd with (nolock) 
	inner join ReportsData..ShipmentHeader sh with (nolock) on sh.transferid=sd.transferid
	inner join ReportsData..locations l with (nolock) on l.locationno=sh.fromlocationno and (locationtype='R' or locationtype = 'C')
	inner join reportsdata..locations ls with (nolock) on ls.locationno = sh.tolocationno and ls.locationtype = 'S'
where sd.DateReceived between @i_StartDate and DATEADD(day,1,@i_EndDate)
	and not exists (select distinct ItemCode
					from ReportsData..InventoryTransfers with (nolock)
					where FromLocationNo=sh.FromLocationNo and ToLocationNo=sh.ToLocationNo 
						and TransferID=sh.TransferID and itemCode=sd.ItemCode)
group by sd.ItemCode,case when (sh.dropshipment)= 0 then 0 else 1 end


insert into #ILSRcvHist
select distinct sum(isnull(r.total_qty,0))
	,r.item
from(
		select
			sum(isnull(rc.total_qty,0))[total_qty]
			,right('00000000000000000000' + rc.item, 20) [item]
		from rils_data..receipt_detail rc with (nolock)
		where rc.company <> 'SUP' 
			and right('00000000000000000000' + rc.item, 20) not in (select itemcode from #ShipHist)
		group by right('00000000000000000000' + rc.item, 20)
	union
		select
			sum(isnull(ar.total_qty,0))[total_qty]
			,right('00000000000000000000' + ar.item, 20)[item]
		from rils_data..AR_RECEIPT_DETAIL ar with (nolock)
		where ar.company <> 'SUP' 
			and right('00000000000000000000' + ar.item, 20) not in (select itemcode from #ShipHist)
		group by right('00000000000000000000' + ar.item, 20)
	)r
group by r.item


if exists (select * from dbo.sysobjects
			where id = object_id(N'[dbo].[#Received]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table #Received
if exists (select * from dbo.sysobjects
			where id = object_id(N'[dbo].[#LastProcessedDate]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table #LastProcessedDate
----set received dates and parent......
/*Next for Last Received*/
create table #Received(
	 itemcode      char(20)
	,firstreceived datetime
	,lastReceived  datetime
	,parent        varchar(5)
	,rcvdqty       int
)
create  clustered  index [IDX_items] on #Received ( [ItemCode])

insert into #Received
select
	distinct
	r.ItemCode
	,min(r.firstreceived)
	,max(r.lastReceived)
	,r.Parent
	,isnull(sum(r.RcvdQty),0)
from(
		select
			distinct
			sd.itemcode [ItemCode]
			,min(sd.ProcessDate)[firstreceived]
			,max(sd.ProcessDate)[lastReceived]
			,'SR' [Parent]
			,isnull(SUM(sd.Qty),0)[RcvdQty]
		from ReportsData..SR_Header_Historical sh with (nolock) 
			inner join ReportsData..SR_Detail_Historical sd with (nolock) on sh.BatchID = sd.BatchID
		where sh.ShipmentType in ('W')
		group by sd.ItemCode
	union
		select
			distinct
			sd.itemcode [ItemCode]
			,min(sd.ProcessDate)[firstreceived]
			,max(sd.ProcessDate)[lastReceived]
			,'SR' [Parent]
			,isnull(SUM(sd.Qty),0)[RcvdQty]
		from ReportsData..SR_Header sh with (nolock) 
			inner join ReportsData..SR_Detail sd with (nolock) on sh.BatchID = sd.BatchID
		where sh.ShipmentType in ('W')
		group by sd.ItemCode
	) r
group by r.ItemCode,r.Parent

insert into #Received
select
	distinct
	r.ItemCode
	,min(r.firstreceived)
	,max(r.lastReceived)
	,r.Parent
	,isnull(sum(r.RcvdQty),0)
from(
		select
			distinct
			sd.itemcode [ItemCode]
			,min(sd.ProcessDate)[firstreceived]
			,max(sd.ProcessDate)[lastReceived]
			,'DS' [Parent]
			,isnull(SUM(sd.Qty),0)[RcvdQty]
		from ReportsData..SR_Header sh with (nolock) 
			inner join ReportsData..SR_Detail sd with (nolock) on sh.BatchID = sd.BatchID
		where sh.ShipmentType in ('R')
		group by sd.ItemCode
	union
		select
			distinct
			sd.itemcode [ItemCode]
			,min(sd.ProcessDate)[firstreceived]
			,max(sd.ProcessDate)[lastReceived]
			,'DS' [Parent]
			,isnull(SUM(sd.Qty),0)[RcvdQty]
		from ReportsData..SR_Header_Historical sh with (nolock) 
			inner join ReportsData..SR_Detail_Historical sd with (nolock) on sh.BatchID = sd.BatchID
		where sh.ShipmentType in ('R')
		group by sd.ItemCode) r
group by r.ItemCode,r.Parent


insert into #received
select
	wr.ItemCode
	,min(wr.firstrecv)
	,max(wr.lastrecv)
	,wr.Parent
	,sum(wr.RcvdQty)
from(
		select
			right('00000000000000000000' + item, 20)[ItemCode]
			,min(receipt_date)[firstrecv]
			,max(receipt_date)[lastrecv]
			,' ' [Parent]
			,isnull(SUM(TOTAL_QTY),0)[RcvdQty]
		from rILS_data..RECEIPT_DETAIL
		where right('00000000000000000000' + item, 20) not in (select distinct itemcode from #received)
		group by right('00000000000000000000' + item, 20)
	union
		select
			right('00000000000000000000' + item, 20)[ItemCode]
			,min(receipt_date)[firstrecv]
			,max(receipt_date)[lastrecv]
			,' ' [Parent]
			,isnull(SUM(TOTAL_QTY),0)[RcvdQty]
		from rILS_data..AR_RECEIPT_DETAIL
		where right('00000000000000000000' + item, 20) not in (select distinct itemcode from #received)
		group by right('00000000000000000000' + item, 20))wr
group by wr.ItemCode,wr.Parent

insert into #received
select
	distinct
	rd.ItemCode
	,min(rh.DistributionPostedDate)
	,max(rh.DistributionPostedDate)
	,'DR' [Parent]
	,isnull(SUM(rd.QtyCounted),0)[RcvdQty]
from ReportsData..ReceiveDetail rd 
	inner join ReportsData..ReceiveHeader rh on rd.Receiver=rh.Receiver
where rh.distributionposteddate > @i_StartDate 
	and rd.itemcode not in (select distinct itemcode from #received)
group by rd.ItemCode

select
	distinct
	itemcode
	,cast(min(firstreceived)as smalldatetime)[firstRcvd]
	,cast(max(lastReceived)as smalldatetime)[LastRcvd]
	,parent
into #LastProcessedDate
from #Received
group by itemcode, parent


---------------------------------------------------------------------------------------------------------
/*GET THE INITIAL ITEMS TO WORK ON*/
-- !! Items with multiple POs will end up with duplicate lines if 2+ of those POs have SpecInstrs
insert into CDC_SDV_WORK(VendorID,ReorderVendorID,ItemCode,Parent,ISBN,ProductType,SectionCode,Title,Cost,Price,MSRP
						,QtyShipped,AmtInvoiced,SchemeID,Reorderable,LastReceived,FirstReceived,FOBPO,FOBItem)
select
	pm.VendorID
	,pm.PurchaseFromVendorID
	,pm.ItemCode
	,'SHIP'[Parent]
	,case ltrim(rtrim(pm.ISBN)) when '' then substring(pmd.upc,1,13) else pm.isbn end [ISBN]
	,pm.ProductType
	,pm.SectionCode
	,case  pm.Title when '' then pm.Description else pm.Title end [Title]
	,pm.Cost
	,pm.Price
	,case when isnumeric(isnull(pm.MfgSuggestedPrice,0))=1 then isnull(pm.MfgSuggestedPrice,0) else 0 end
	,ship.shipQty
	,(pm.Cost * ISNULL(ship.shipQty,0))
	,pmd.SchemeID
	,pm.Reorderable
	,lastRcv.lastRcvd
	,lastRcv.firstRcvd
	,cast(o.FOBPO as varchar(250))
	,cast(o.FOBItem as varchar(250))
from ReportsData..ProductMaster pm with (nolock) 
	inner join ReportsData..ProductMasterDist PMD with (nolock) on pmd.ItemCode=pm.ItemCode
	inner join (select distinct ItemCode,SUM(qtyshipped) [shipQty]
				from #ShipHist
				group by ItemCode
		) ship on ship.ItemCode = pm.ItemCode
	left join (select ItemCode
					,cast(min(firstRcvd) as smalldatetime)[firstRcvd]
					,cast(max(LastRcvd) as smalldatetime)[lastRcvd]
				from #LastProcessedDate
				group by ItemCode
		) lastRcv on lastRcv.ItemCode = pm.ItemCode
	left join (select distinct oh.PONumber,od.ItemCode
					,cast(oh.SpecInstructions as varchar(250))[FOBPO]
					,cast(od.SpecialInstructions as varchar(250))[FOBItem]
				from ReportsData..OrderHeader oh with(nolock) 
					inner join ReportsData..OrderDetail od with(nolock) on oh.PONumber=od.PONumber
				where (ISNULL(oh.SpecInstructions,'')<>'' or ISNULL(od.SpecialInstructions,'')<>'')
		) o on o.ItemCode=pm.itemcode and o.PONumber=pm.LastPurchaseOrder
where pm.ItemCode not in (select distinct NewItemCode from ReportsData..RecvDtlItemsCreated)
	and pm.ItemCode not in (select distinct ItemCode from ReportsData..RecvDtlItemsCreated)
	and (pm.CreateDate between @i_StartDate and @i_EndDate 
			or pm.Reorderable='Y' 
			or lastrcv.lastRcvd between @i_StartDate and @i_EndDate)


----CDC rcvd info
insert into CDC_SDV_WORK(VendorID,ReorderVendorID,ItemCode,Parent,ISBN,ProductType,SectionCode,Title,Cost,Price,MSRP
						,QtyShipped,AmtInvoiced,SchemeID,Reorderable,LastReceived,FirstReceived,FOBPO,FOBItem)
select
	pm.VendorID
	,pm.PurchaseFromVendorID
	,pm.ItemCode
	,case when pm.Reorderable='Y'  then ' ' else 'RCVD'end[Parent]
	,case ltrim(rtrim(pm.ISBN)) when '' then substring(pmd.upc,1,13) else pm.isbn end [ISBN]
	,pm.ProductType
	,pm.SectionCode
	,case  pm.Title when '' then pm.Description else pm.Title end [Title]
	,pm.Cost
	,pm.Price
	,case when isnumeric(isnull(pm.MfgSuggestedPrice,0))=1 then isnull(pm.MfgSuggestedPrice,0) else 0 end
	,rcv.QtyRcvd
	,(pm.Cost * ISNULL(rcv.QtyRcvd,0))
	,pmd.SchemeID
	,pm.Reorderable
	,lastRcv.lastRcvd
	,lastRcv.firstRcvd
	,cast(o.FOBPO as varchar(250))
	,cast(o.FOBItem as varchar(250))
from ReportsData..ProductMaster pm with (nolock) 
	inner join ReportsData..ProductMasterDist PMD with (nolock) on pmd.ItemCode=pm.ItemCode
	inner join #ILSRcvHist rcv on rcv.itemcode = pm.itemcode
	left  join (select ItemCode
					,cast(min(firstRcvd) as smalldatetime)[firstRcvd]
					,cast(max(LastRcvd) as smalldatetime)[lastRcvd]
				from #LastProcessedDate
				group by ItemCode
		)lastRcv on lastRcv.ItemCode = pm.ItemCode
	left join (select distinct oh.PONumber,od.ItemCode
					,cast(oh.SpecInstructions as varchar(250))[FOBPO]
					,cast(od.SpecialInstructions as varchar(250))[FOBItem]
				from ReportsData..OrderHeader oh with(nolock) 
					inner join ReportsData..OrderDetail od with(nolock) on oh.PONumber=od.PONumber
				where (ISNULL(oh.SpecInstructions,'')<>'' or ISNULL(od.SpecialInstructions,'')<>'')
		)o on o.ItemCode=pm.itemcode and o.PONumber=pm.LastPurchaseOrder
where (pm.CreateDate between @i_StartDate and @i_EndDate 
		or pm.Reorderable='Y' 
		or lastrcv.lastRcvd between @i_StartDate and @i_EndDate)

/*CAN ANY BASE INVENTORY*/
delete CDC_SDV_WORK 
where ItemCode in (select ItemCode from ReportsData..BaseInventory with (nolock)) 
	or SCHEMEID='BASE INVENTORY' or VendorID = 'WHPBSUPPLY' or ReorderVendorID='WHPBSUPPLY'


/*next 2 for transfers*/
--get non-damage transfers.....
update s
set s.QtyTrans=isnull(it.QtyShipped,0)
from CDC_SDV_WORK s
	inner join (select SUM(ISNULL(sd.QTY,0))as QtyShipped
					,sd.ItemCode
				from ReportsData..ShipmentDetail sd
					inner join ReportsData..ShipmentHeader sh on sh.transferid=sd.transferid
				where sd.DateReceived between @i_StartDate and DATEADD(day,1,@i_EndDate) and sh.DropShipment=0
					and exists (select ItemCode 
								from ReportsData..InventoryTransfers
								where FromLocationNo=sh.FromLocationNo and ToLocationNo=sh.ToLocationNo 
									and TransferID=sh.TransferID and itemCode=sd.ItemCode)
					and sh.ToLocationNo<>'00300'
				--exclude transfers to damage.
				group by sd.ItemCode
		) it on it.ItemCode=s.ItemCode

--get damage transfers.....
update s
set s.QtyDamaged=isnull(it.QtyShipped,0)
from CDC_SDV_WORK s
	inner join (select SUM(ISNULL(sd.QTY,0))as QtyShipped
					,sd.ItemCode
				from ReportsData..ShipmentDetail sd
					inner join ReportsData..ShipmentHeader sh on sh.transferid=sd.transferid
				where sd.DateReceived between @i_StartDate and DATEADD(day,1,@i_EndDate) and sh.DropShipment=0
					and exists ( select ItemCode
								from ReportsData..InventoryTransfers
								where FromLocationNo=sh.FromLocationNo and ToLocationNo=sh.ToLocationNo 
									and TransferID=sh.TransferID and itemCode=sd.ItemCode)
					and sh.ToLocationNo='00900'
				--get only damage transfers.
				group by sd.ItemCode
		) it on it.ItemCode=s.ItemCode


/*Next update dropship qty with store received qty*/
-- !!Updates ALL of the ShipQty to the StoreRcvQty if ANY shipments of an item were dropshipped.
update s
set s.QtyShipped =(select sum(x.Qty)
					from((select isnull(SUM(Qty),0)[Qty]
							from ReportsData..SR_Detail
							where itemcode=s.itemcode)
						union
						 (select isnull(SUM(Qty),0)[Qty]
							from ReportsData..SR_Detail_Historical
							where itemcode=s.itemcode)) x)
from CDC_SDV_WORK s --join #Received r on s.ItemCode=r.itemcode
	inner join (select distinct ItemCode
				from #ShipHist
				where DropShip=1
		)ship on ship.ItemCode=s.ItemCode
where LTRIM(RTRIM(s.Parent)) in ('DS','SHIP')


/*Next update parent*/
update s
-- !!Parent isn't part of the join condition, also not seeing why s wouldn't already have the correct First/Last Received dates.???
set s.parent = case(pd.parent) when 'DS' then ' ' when 'SR' then ' ' when 'DR' then ' ' else s.Parent end
	,s.LastReceived=(select max(LastRcvd)
						from #LastProcessedDate
						where itemcode=s.ItemCode)
	,s.FirstReceived=(select min(firstRcvd)
						from #LastProcessedDate
						where itemcode=s.ItemCode)
from CDC_SDV_WORK s 
	inner join #LastProcessedDate pd on pd.itemcode=s.itemcode

update CDC_SDV_WORK set parent = ' ' where lastreceived is null and (Reorderable = 'N' or QtyShipped = 0)
update CDC_SDV_WORK set parent = 'SRPR' where lastreceived is null and Reorderable = 'Y' and QtyShipped > 0
--update CDC_SDV_WORK set Parent = ' ' where Parent='RCVD' and ItemCode in (select distinct itemcode from #ShipHist)

drop table #ShipHist
drop table #ILSRcvHist
drop table #Received
drop table #LastProcessedDate


if exists (select * from dbo.sysobjects
			where id = object_id(N'[dbo].[CDC_SDV_ONHAND]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table CDC_SDV_ONHAND

/*next 2 for on hand*/
select
	SUM(isnull(pv.QuantityOnHand,0))[Qty]
	,pv.ItemCode
into CDC_SDV_ONHAND
from ReportsData..ProductInventory pv  with (nolock) 
	inner join (select distinct itemcode from CDC_SDV_WORK) s on s.ItemCode = pv.ItemCode
group by pv.ItemCode

update CDC_SDV_WORK
set OnHand = q.Qty 
from CDC_SDV_WORK s 
	inner join CDC_SDV_ONHAND q on s.ItemCode=q.ItemCode

drop table CDC_SDV_ONHAND

update CDC_SDV_WORK set QtyTrans=0 where QtyTrans is null
update CDC_SDV_WORK set OnHand=0 where OnHand is null


----get UPC/ISBN items..................................................................
select
	pm.ItemCode
	,pmd.ReportItemCode
into #upcItems
from ReportsData..ProductMaster pm with (nolock) 
	inner join ReportsData..ProductMasterDist pmd with (nolock) on pm.ItemCode=pmd.ItemCode
where pm.ItemCode in (select distinct right('00000000000000000000' + replace(ItemAlias,'UPC',''),20)
						from ReportsData..ProductMaster
						where ItemAlias like 'UPC%')


--------------------------------------------------------------------------------------------------------------------------------------
insert into CDC_SDV_SalesData
select
	sum(t.ExtendedAmt)[ExtendedAmt]
	,sum(t.RegisterPrice)[RegisterPrice]
	,sum(t.QtySold)[QtySold]
	,sum(t.QtyReturned)[QtyReturned]
	,sum(t.Coupons)[Coupons]
	,sum(t.CouponAmt)[CouponAmt]
	,sum(t.markeddown)[markeddown]
	,sum(t.QtyDisc)[QtyDisc]
	,sum(t.DiscAmt)[DiscAmt]
	,t.ItemCode
from(
		select
			cast(sum(case when sih.IsReturn='N' then sih.ExtendedAmt else 0 end)as money)[ExtendedAmt]
			,cast(sum(case when sih.IsReturn='N' then sih.RegisterPrice else 0 end)as money)[RegisterPrice]
			,sum(case when sih.IsReturn='N' then sih.Quantity else 0 end) [QtySold]
			,sum(case when sih.IsReturn='Y' then sih.Quantity else 0 end) [QtyReturned]
			,sum(case when sih.ODPCFlag='C' then sih.Quantity else 0 end) [Coupons]
			,cast(sum(case when sih.ODPCFlag='C' then sih.DiscountAmt else 0 end)as money) [CouponAmt]
			,sum(case when sih.UnitPrice > sih.RegisterPrice then 1 else 0 end) [markeddown]
			,sum(case when sih.discountpct > 0 and sih.IsReturn='N' then 1 else 0 end) [QtyDisc]
			,cast(sum(case when sih.DiscountAmt > 0 and sih.IsReturn='N' then sih.DiscountAmt else 0 end)as money) [DiscAmt]
			,sih.ItemCode
		from rHPB_Historical.dbo.SalesItemHistory sih with (nolock)
			inner join (select distinct itemcode from CDC_SDV_WORK) s on s.ItemCode = sih.ItemCode
		where sih.XactionType='S' and sih.status='A' and sih.BusinessDate >= @i_StartDate and sih.BusinessDate <=@i_SalesEnding
			and sih.ItemCode not in (select distinct itemcode from #upcItems)
		group by sih.ItemCode
	union
		select
			cast(sum(case when sih.IsReturn='N' then sih.ExtendedAmt else 0 end)as money)[ExtendedAmt]
			,cast(sum(case when sih.IsReturn='N' then sih.RegisterPrice else 0 end)as money)[RegisterPrice]
			,sum(case when sih.IsReturn='N' then sih.Quantity else 0 end) [QtySold]
			,sum(case when sih.IsReturn='Y' then sih.Quantity else 0 end) [QtyReturned]
			,sum(case when sih.ODPCFlag='C' then sih.Quantity else 0 end) [Coupons]
			,cast(sum(case when sih.ODPCFlag='C' then sih.DiscountAmt else 0 end)as money) [CouponAmt]
			,sum(case when sih.UnitPrice > sih.RegisterPrice then 1 else 0 end) [markeddown]
			,sum(case when sih.discountpct > 0 and sih.IsReturn='N' then 1 else 0 end) [QtyDisc]
			,cast(sum(case when sih.DiscountAmt > 0 and sih.IsReturn='N' then sih.DiscountAmt else 0 end)as money) [DiscAmt]
			,u.ReportItemCode
		from rhpb_historical..SalesItemHistory sih with(nolock) 
			inner join #upcItems u on sih.ItemCode=u.ItemCode
		where sih.XactionType='S' and sih.Status = 'A' and sih.BusinessDate >= @i_StartDate and sih.BusinessDate <=@i_SalesEnding
		group by u.ReportItemCode) t
group by t.ItemCode

update w 
set w.QtySold=s.QuantitySold
	,w.RegisterPrice=s.RegisterPrice
	,w.QtyReturned=s.Returned
	,w.ExtendedAmt=s.ExtendedAmt
	,w.Coupons=s.Coupons
	,w.CouponAmt=s.CouponAmt
	,w.QtyDisc=s.QtyDisc
	,w.DiscAmt=s.DiscAmt
	,w.QtyMarkedDown=s.MarkedDown
from CDC_SDV_WORK w 
	inner join CDC_SDV_SalesData s on w.ItemCode=s.ItemCode


if OBJECT_ID('tempdb..#online_sales') is not null drop table #online_sales
create table #online_sales(
	ItemCode        nvarchar(25)
	,SellingPrice    money 
	,[OnlineQtySold] numeric(19)
	,DateSold        datetime,
)

insert into #online_sales
select
	ItemCode
	,(cast(avg(SellingPrice)as money)) [ExtendedAmt]
	,sum(Quantity) [OnlineQtySold]
	,max(DateSold)
from reportsdata..Sales_OnlineMarketPlaces_Distribution sod with(nolock)
where sod.DateSold >= @i_StartDate and sod.DateSold <=@i_SalesEnding
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
create table #TBRIitems(
	itemcode char(20)
)
create  clustered  index [IDX_items] on #TBRIitems ( [ItemCode])
insert into #TBRIitems
select
	distinct
	od.ItemCode
from ReportsData..OrderDetail od with(nolock) 
	inner join ReportsData..OrderHeader oh with(nolock) on od.PONumber=oh.PONumber
	inner join ReportsData..CDC_TradeShowRollUpNew tsr with(nolock) on tsr.ItemCode=od.ItemCode
	inner join ReportsData..ProductMaster pm with(nolock) on od.ItemCode=pm.ItemCode
where pm.UserChar15='TTB' and oh.LocationNo='00944' and isnull(oh.SkeletonCreatedFrom,'')='' 
	and oh.CreatedFromRequisition=0 and oh.CancelDate is null


/*Received POs........................................................................................................*/
create table #TBRIReceived(
	itemcode char(20)
	,ponumber char(6)
)
create  clustered  index [IDX_items] on #TBRIReceived ( [ItemCode])

----run archive table first for CDC shipments to get min dates for items.......................................
insert into #TBRIReceived
--archive SR tables / CDC shipments....
select distinct sd.itemcode [ItemCode]
	,right(sh.ShipmentNo,6) [PONumber]
from ReportsData..SR_Header_Historical sh with (nolock) 
	inner join ReportsData..SR_Detail_Historical sd with (nolock) on sh.BatchID = sd.BatchID
	inner join #TBRIitems i on sd.ItemCode=i.itemcode 
	inner join ReportsData..OrderHeader oh with(nolock) on oh.PONumber=right(sh.ShipmentNo,6)
where sh.ShipmentType in ('W','R')

insert into #TBRIReceived
--current SR tables / CDC shipments....
select distinct sd.itemcode [ItemCode]
	,right(sh.ShipmentNo,6) [PONumber]
from ReportsData..SR_Header sh with (nolock) 
	inner join ReportsData..SR_Detail sd with (nolock) on sh.BatchID = sd.BatchID
	inner join #TBRIitems i on sd.ItemCode=i.itemcode 
	inner join ReportsData..OrderHeader oh with(nolock) on oh.PONumber=right(sh.ShipmentNo,6)
where sh.ShipmentType in ('W','R')

insert into #TBRIReceived
--get WMS recevied.....
select distinct right('00000000000000000000' + item, 20)[ItemCode]
	,case when isnumeric(PURCHASE_ORDER_ID)=1 then PURCHASE_ORDER_ID else left(PURCHASE_ORDER_ID,6)end [PONumber]
from rILS_data..RECEIPT_DETAIL 
	inner join #TBRIitems i on right('00000000000000000000' + item, 20)=i.itemcode
where PURCHASE_ORDER_ID is not null

insert into #TBRIReceived
--get WMS archived recevied.....
select distinct right('00000000000000000000' + item, 20)[ItemCode]
	,case when isnumeric(PURCHASE_ORDER_ID)=1 then PURCHASE_ORDER_ID else left(PURCHASE_ORDER_ID,6)end [PONumber]
from rILS_data..AR_RECEIPT_DETAIL 
	inner join #TBRIitems i on right('00000000000000000000' + item, 20)=i.itemcode
where PURCHASE_ORDER_ID is not null

----get final results......................................................................................................................................
insert into CDC_SDV_PENDING(FirstReceived,LastReceived,LastPO,VendorID,ReorderVendorID,ItemCode,Parent,ISBN,ProductType,Buyer
							,SectionCode,Title,Cost,Price,MSRP,QtyShipped,AmtInvoiced,SchemeID,Reorderable,FOBPO,FOBItem)
select
	oh.PODate
	,oh.PODate
	,od.PONumber
	,pm.VendorID
	,pm.PurchaseFromVendorID
	,pm.ItemCode
	,'TBRI'[Parent]
	,case ltrim(rtrim(pm.ISBN)) when '' then substring(pmd.upc,1,13) else pm.isbn end [ISBN]
	,pm.ProductType
	,oh.BuyerID
	,pm.SectionCode
	,case  pm.Title when '' then pm.Description else pm.Title end [Title]
	,pm.Cost
	,pm.Price
	,case when isnumeric(isnull(pm.MfgSuggestedPrice,0))=1 then isnull(pm.MfgSuggestedPrice,0) else 0 end [MSRP]
	,od.OrderQty
	,(pm.Cost * ISNULL(od.OrderQty,0))[AmtInvoiced]
	,od.SchemeID
	,pm.Reorderable
	,cast(oh.SpecInstructions as varchar(250))[FOBPO]
	,cast(od.SpecialInstructions as varchar(250))[FOBItem]
from ReportsData..OrderHeader oh with(nolock) 
	inner join ReportsData..OrderDetail od with(nolock) on oh.PONumber=od.PONumber
	inner join #TBRIitems i on i.itemcode=od.ItemCode 
	inner join ReportsData..ProductMaster pm with(nolock) on i.itemcode=pm.ItemCode
	inner join ReportsData..ProductMasterDist pmd with(nolock) on pmd.ItemCode=pm.ItemCode
	left  join (select distinct itemcode,PONumber from #TBRIReceived)r on r.itemcode=i.itemcode and oh.PONumber=r.ponumber
where oh.LocationNo='00944' and oh.CreatedFromRequisition=0 and r.itemcode is null
	and isnull(oh.PODate,GETDATE())>DATEADD(year,-1,getdate()) and oh.CancelDate is null


----now get all other pending items excluded those in the previous step......................................................................................
insert into CDC_SDV_PENDING(FirstReceived,LastReceived,LastPO,VendorID,ReorderVendorID,ItemCode,Parent,ISBN,ProductType,Buyer
							,SectionCode,Title,Cost,Price,MSRP,QtyShipped,AmtInvoiced,SchemeID,Reorderable,FOBPO,FOBItem)
select
	oh.PODate
	,oh.PODate
	,od.PONumber
	,pm.VendorID
	,pm.PurchaseFromVendorID
	,pm.ItemCode
	,'PEND'[Parent]
	,case ltrim(rtrim(pm.ISBN)) when '' then substring(pmd.upc,1,13) else pm.isbn end [ISBN]
	,pm.ProductType
	,oh.BuyerID
	,pm.SectionCode
	,case  pm.Title when '' then pm.Description else pm.Title end [Title]
	,pm.Cost
	,pm.Price
	,case when isnumeric(isnull(pm.MfgSuggestedPrice,0))=1 then isnull(pm.MfgSuggestedPrice,0) else 0 end
	,od.OrderQty
	,(pm.Cost * ISNULL(od.OrderQty,0))
	,od.SchemeID
	,pm.Reorderable
	,cast(oh.SpecInstructions as varchar(250))[FOBPO]
	,cast(od.SpecialInstructions as varchar(250))[FOBItem]
from ReportsData..ProductMaster pm with (nolock) 
	inner join ReportsData..ProductMasterDist PMD with (nolock) on pmd.ItemCode=pm.ItemCode
	inner join ReportsData..OrderDetail od with (nolock) on od.ItemCode=pm.ItemCode --AND od.PONumber=pm.LastPurchaseOrder
	inner join ReportsData..OrderHeader oh with (nolock) on oh.PONumber=od.PONumber
where od.DistributionType!='A' and isnull(oh.POType,'') not in ('S','C') 
	and oh.PODate > DATEADD(MONTH, -12,GETDATE()) and oh.CancelDate is null
	and not exists (select *
					from ReportsData..ShipmentDetail sd with (nolock) 
						inner join ReportsData..ShipmentHeader sh with (nolock) on sh.TransferID=sd.TransferID
					where sd.ItemCode=od.ItemCode)
	and not exists (select * from CDC_SDV_WORK where ItemCode=pm.ItemCode) 
	and not exists (select * from CDC_SDV_PENDING where ItemCode=pm.ItemCode)


/*INSERT WHATEVER PENDING IS LEFT TO THE WORK TABLE*/
insert into CDC_SDV_WORK(VendorID,ReorderVendorID,ItemCode,Parent,ISBN,ProductType,Buyer,SectionCode,Title,Cost
						,Price,MSRP,QtyShipped,QtyTrans,QtyDamaged,QtySold,QtyReturned,RegisterPrice,ExtendedAmt
						,OnHand,AmtInvoiced,Reorderable,LastPO,LastReceived,FirstReceived,SchemeID)
select
	VendorID
	,ReorderVendorID
	,ItemCode
	,Parent
	,ISBN
	,ProductType
	,Buyer
	,SectionCode
	,Title
	,Cost
	,Price
	,MSRP
	,QtyShipped
	,QtyTrans
	,QtyDamaged
	,QtySold
	,QtyReturned
	,RegisterPrice
	,ExtendedAmt
	,OnHand
	,AmtInvoiced
	,Reorderable
	,LastPO
	,LastReceived
	,FirstReceived
	,SchemeID
from CDC_SDV_PENDING


/*CAN THE TEMP POs TABLE IN CASE SOMETHING HAPPENED LAST RUN...*/
if exists (select * from dbo.sysobjects
			where id = object_id(N'[dbo].[CDC_SDV_POs]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table CDC_SDV_POs

/*BUILD TEMP TABLE WITH PO RELATED INFO*/
--LastPO
select
	MAX(sd.PONumber)[PONumber]
	,sd.ItemCode
	,CAST(''as varchar(250))[FOBPO]
	,CAST(''as varchar(250))[FOBItem]
into #tmpPOs
from CDC_SDV_WORK s 
	inner join ReportsData..ShipmentDetail sd with (nolock) on sd.itemcode=s.itemcode
where sd.PONumber not in (select distinct LastPO from CDC_SDV_PENDING)
group by sd.ItemCode

insert into #tmpPOs
select
	MAX(sd.PONumber)[PONumber]
	,sd.ItemCode
	,cast(oh.SpecInstructions as varchar(250))[FOBPO]
	,cast(sd.SpecialInstructions as varchar(250))[FOBItem]
from CDC_SDV_WORK s inner join ReportsData..OrderDetail sd with (nolock) on sd.itemcode=s.itemcode
	inner join ReportsData..OrderHeader oh with(nolock) on sd.PONumber=oh.PONumber
where sd.PONumber not in (select distinct PONumber from #tmpPOs where ItemCode=sd.ItemCode) 
	and sd.PONumber not in (select distinct p.LastPO from CDC_SDV_PENDING p)
	and isnull(oh.SkeletonCreatedFrom,'')='' and oh.CreatedFromRequisition=0 and oh.CancelDate is null
group by sd.ItemCode,oh.SpecInstructions,sd.SpecialInstructions

select
	MAX(s.PONumber)[PONumber]
	,s.ItemCode
	,s.FOBPO
	,s.FOBItem
into CDC_SDV_POs
from #tmpPOs s
group by s.ItemCode,s.FOBPO,s.FOBItem


/*UPDATE THE WORK TABLE WITH LAST PO*/
update CDC_SDV_WORK
set FOBPO=s.FOBPO,FOBItem=s.FOBItem
from CDC_SDV_WORK s 
	inner join CDC_SDV_POs sd on sd.itemcode=s.itemcode

update t
set t.FOBItem=cast(od.SpecialInstructions as varchar(250))
	,t.FOBPO=cast(oh.SpecInstructions as varchar(250))
from CDC_SDV_WORK t 
	inner join ReportsData..OrderDetail od on od.ItemCode=t.ItemCode and od.PONumber=t.LastPO
	inner join ReportsData..OrderHeader oh on t.LastPO=oh.PONumber	
where ISNULL(t.FOBItem,'')='' and isnull(od.SpecialInstructions,'')<>''

update t
set t.FOBItem=cast(od.SpecialInstructions as varchar(250))
	,t.FOBPO=cast(oh.SpecInstructions as varchar(250))
from CDC_SDV_WORK t 
	inner join ReportsData..OrderDetail od on od.ItemCode=t.ItemCode and od.PONumber=t.LastPO
	inner join ReportsData..OrderHeader oh on t.LastPO=oh.PONumber	
where ISNULL(t.FOBPO,'')='' and isnull(oh.SpecInstructions,'')<>''

update CDC_SDV_WORK
set LastPO=sd.PONumber
from CDC_SDV_WORK s 
	inner join CDC_SDV_POs sd on sd.itemcode=s.itemcode
where Parent<>'TBRI'

drop table CDC_SDV_POs


-- get last PO# from ProdMaster for Assortment Items.... 10/22/2010 JoeyB
update CDC_SDV_WORK
set LastPO = pm.lastpurchaseorder
from CDC_SDV_WORK s 
	inner join ReportsData..ProductMaster pm with (nolock) on pm.ItemCode = s.ItemCode
where right(pm.ItemCode,8) > '19999999' or s.LastPO is null

----get publisher/author.....
update c
set c.Publisher=left(i.PublisherName,250)
	,c.Author=left(i.Author,250)
from CDC_SDV_WORK c 
	inner join ReportsData..ISBN13 i on i.ISBN=c.ISBN

/*CAN THE PENDING TABLE*/
drop table CDC_SDV_PENDING
drop table #TBRIitems
drop table #TBRIReceived

/*ADD BUYERS NAME*/----changed the buyer section to get original buyer instead of buy associated with LastPO.... JoeyB. 4/1/2015
select
	oh.PONumber
	,od.ItemCode
	,cast(' 'as varchar(30))[Buyer]
	,min(oh.PODate)[PODate]
into #BuyerPO
from ReportsData..OrderHeader oh 
	inner join ReportsData..OrderDetail od on oh.PONumber=od.PONumber
	inner join CDC_SDV_WORK csw on csw.ItemCode=od.ItemCode
group by oh.PONumber,od.ItemCode

update bp
set bp.Buyer=b.[Name]
from #BuyerPO bp 
	inner join ReportsData..OrderHeader oh with (nolock) on bp.PONumber=oh.PONumber and bp.PODate=oh.PODate
	inner join ReportsData..Buyers b with (nolock) on b.BuyerID=oh.BuyerID

update CDC_SDV_WORK
set Buyer=bp.Buyer
from CDC_SDV_WORK s 
	inner join #BuyerPO bp on s.ItemCode=bp.ItemCode

update s
set s.Buyer=b.Name
from CDC_SDV_WORK s 
	inner join ReportsData..OrderHeader oh on s.LastPO=oh.PONumber
	inner join ReportsData..Buyers b on oh.BuyerID=b.BuyerID
where ltrim(rtrim(ISNULL(s.Buyer,'')))=''

-- Added the below update statement to update sectioncodes instead of doing a join.... 10/22/2010 JoeyB....
update CDC_SDV_WORK 
set SectionCode = UPPER(ISNULL(smd.SectionCode, 'NONE'))
from CDC_SDV_WORK cdc 
	inner join ReportsData..SectionMasterForDIPS smd with (nolock) on smd.ItemCode = cdc.ItemCode

/*DO SOME HOUSE CLEANING...*/
delete from CDC_SDV_WORK 
where VendorID = 'WHPBSUPPLY' or ReorderVendorID = 'WHPBSUPPLY' or SchemeID='ECOM'

update CDC_SDV_WORK set QtyReturned=0 where QtyReturned is null
update CDC_SDV_WORK set QtySold=0 where QtySold is null
update CDC_SDV_WORK set RegisterPrice=0 where RegisterPrice is null
update CDC_SDV_WORK set ExtendedAmt=0 where ExtendedAmt is null
update CDC_SDV_WORK set QtyTrans=0 where QtyTrans is null
update CDC_SDV_WORK set OnHand=0 where OnHand is null
update CDC_SDV_WORK set Parent='' where Parent is null
update CDC_SDV_WORK set Buyer='' where Buyer is null
update CDC_SDV_WORK set AmtInvoiced = 0 where ISNULL(LastPO,'')=''
update CDC_SDV_WORK set QtyDisc=0 where QtyDisc is null
update CDC_SDV_WORK set DiscAmt=0 where DiscAmt is null
update CDC_SDV_WORK set Coupons=0 where Coupons is null
update CDC_SDV_WORK set CouponAmt=0 where CouponAmt is null
update CDC_SDV_WORK set QtyDamaged=0 where QtyDamaged is null
update CDC_SDV_WORK set QtyMarkedDown=0 where QtyMarkedDown is null


----update UPC/ISBN items to their parent itemcode..........
update t
set t.itemcode=u.reportitemcode
	,t.Reorderable=(select top 1 Reorderable
					from CDC_SDV_WORK
					where ItemCode=u.reportitemcode)
	,t.QtyShipped=0
	,t.VendorID=(select top 1 pm.vendorid
				from ReportsData..ProductMaster pm
				where pm.ItemCode=u.reportitemcode)
	,t.ReorderVendorID=(select top 1 pm.PurchaseFromVendorID
						from ReportsData..ProductMaster pm
						where pm.ItemCode=u.reportitemcode)
	,t.Parent=(select top 1 Parent
				from CDC_SDV_WORK
				where ItemCode=u.reportitemcode)
	,t.SchemeID=(select top 1 SchemeID
				from CDC_SDV_WORK
				where ItemCode=u.reportitemcode)
	,t.LastReceived=(select top 1 LastReceived
					from CDC_SDV_WORK
					where ItemCode=u.reportitemcode)
	,t.FirstReceived=(select top 1 FirstReceived
					from CDC_SDV_WORK
					where ItemCode=u.reportitemcode)
	,t.Buyer=(select top 1 Buyer
				from CDC_SDV_WORK
				where ItemCode=u.reportitemcode)
	,t.LastPO=(select top 1 LastPO
				from CDC_SDV_WORK
				where ItemCode=u.reportitemcode)
	,t.ISBN=(select top 1 ISBN
			from CDC_SDV_WORK
			where ItemCode=u.reportitemcode)
	,t.AmtInvoiced=0
from CDC_SDV_WORK t 
	inner join #upcitems u on t.itemcode=u.itemcode

select distinct
	 VendorID
	,ReorderVendorID
	,ItemCode
	,Parent
	,ISBN
	,ProductType
	,Buyer
	,SectionCode
	,Title
	,Cost
	,Price
	,MSRP
	,sum(isnull(QtyShipped,0))[QtyShipped]
	,sum(isnull(QtyTrans,0))[QtyTrans]
	,sum(isnull(QtyDamaged,0))[QtyDamaged]
	,sum(isnull(QtySold,0))[QtySold]
	,sum(isnull(QtyMarkedDown,0))[QtyMarkedDown]
	,sum(isnull(QtyReturned,0))[QtyReturned]
	,sum(isnull(RegisterPrice,0))[RegisterPrice]
	,sum(isnull(ExtendedAmt,0))[ExtendedAmt]
	,sum(isnull(OnHand,0))[OnHand]
	,sum(isnull(AmtInvoiced,0))[AmtInvoiced]
	,Reorderable
	,max(LastPO)[LastPO]
	,max(LastReceived)[LastReceived]
	,min(FirstReceived)[FirstReceived]
	,max(SchemeID)[SchemeID]
	,max(FOBPO)[FOBPO]
	,max(FOBItem)[FOBItem]
	,max(Publisher)[Publisher]
	,max(Author)[Author]
	,sum(isnull(Coupons,0))[Coupons]
	,sum(isnull(CouponAmt,0))[CouponAmt]
	,sum(isnull(QtyDisc,0))[QtyDisc]
	,sum(isnull(DiscAmt,0))[DiscAmt]
into #CDC_TradeShowRollUp
from CDC_SDV_WORK
where ItemCode not in (select ItemCode from #upcItems) 
	and Parent<>'TBRI'
group by VendorID,ReorderVendorID,ItemCode,Parent,ISBN,ProductType,Buyer,SectionCode,Title,Cost,Price,MSRP,Reorderable


insert into #CDC_TradeShowRollUp
select
	 VendorID
	,ReorderVendorID
	,ItemCode
	,Parent
	,ISBN
	,ProductType
	,Buyer
	,SectionCode
	,Title
	,Cost
	,Price
	,MSRP
	,QtyShipped
	,QtyTrans
	,QtyDamaged
	,QtySold
	,QtyMarkedDown
	,QtyReturned
	,RegisterPrice
	,ExtendedAmt
	,OnHand
	,AmtInvoiced
	,Reorderable
	,LastPO
	,LastReceived
	,FirstReceived
	,SchemeID
	,FOBPO
	,FOBItem
	,Publisher
	,Author
	,Coupons
	,CouponAmt
	,QtyDisc
	,DiscAmt
from CDC_SDV_WORK
where Parent='TBRI'

----update results with any BT returns....
select
	 it.ItemCode
	,sum(it.TransferQty)[TotalReturns]
into #BSRtn
from ReportsData..InventoryTransfers it with(nolock) 
	inner join #CDC_TradeShowRollUp ru on it.ItemCode=ru.ItemCode
where it.ToLocationNo='00300'
group by it.ItemCode

delete from #CDC_TradeShowRollUp 
	where VendorID='WHPBSUPPLY' 
		or ReorderVendorID = 'WHPBSUPPLY'

----get Wholesale values......
select
	g.ITEMNMBR
	,sum(isnull(g.QUANTITY,0))[QUANTITY]
	,cast(sum(isnull(g.XTNDPRCE,0))as money)[XTNDPRCE]
into #TXB
from(
		select
			 sop.ITEMNMBR
			,(sop.QTYTOINV)[QUANTITY]
			,(sop.XTNDPRCE)[XTNDPRCE]
		from ReportsData..TB_SOP10100 soph 
			inner join reportsdata..TB_SOP10200 sop on soph.SOPNUMBE=sop.SOPNUMBE
			inner join (select distinct ItemCode from #CDC_TradeShowRollUp) 
				as c on c.ItemCode=right('00000000000000000000'+ltrim(rtrim(sop.ITEMNMBR)),20)
		where soph.SOPTYPE=3 and soph.CUSTNMBR not in ('SAMPLE','REPS') and soph.DOCID='STD' and soph.BCHSOURC !='Sales Void'
			and soph.CUSTNMBR not like 'MRDC%' and soph.CUSTNMBR not like 'RDC%' and soph.CUSTNMBR not like 'TTB%'
		group by sop.ITEMNMBR,sop.QTYTOINV,sop.XTNDPRCE
	union
		select
			sop.ITEMNMBR
			,(sop.QTYTOINV)[QUANTITY]
			,(sop.XTNDPRCE)[XTNDPRCE]
		from ReportsData..TB_SOP30200 soph 
			inner join ReportsData..TB_SOP30300 sop on soph.SOPNUMBE=sop.SOPNUMBE
			inner join (select distinct ItemCode from #CDC_TradeShowRollUp) 
				as c on c.ItemCode=right('00000000000000000000'+ltrim(rtrim(sop.ITEMNMBR)),20)
		where soph.SOPTYPE=3 and soph.CUSTNMBR not in ('SAMPLE','REPS') and soph.DOCID='STD' and soph.BCHSOURC !='Sales Void'
			and soph.CUSTNMBR not like 'MRDC%' and soph.CUSTNMBR not like 'RDC%' and soph.CUSTNMBR not like 'TTB%'
		group by sop.ITEMNMBR,sop.QTYTOINV,sop.XTNDPRCE) g
group by g.ITEMNMBR


------reset status if out of stock....
update tsr
set tsr.Parent=''
from #CDC_TradeShowRollUp tsr
where tsr.Parent='RCVD' 
	and (tsr.ItemCode in (select distinct right('00000000000000000000'+item,20)[Item]
							from ReportsData..CDC_OOS_ItemLog
							where right('00000000000000000000'+item,20) 
								not in (select ItemCode from rILS_DATA..WMSAvailableQty))
		or tsr.ItemCode in (select distinct right('00000000000000000000'+ltrim(rtrim(ITEMNMBR)),20)
							from #TXB
							where cast(isnull(QUANTITY,0)as int)>0))




--clear the table for insert.....................................................................................................................................
truncate table ReportsData..CDC_TradeShowRollUpNEW

------/*INSERT THE WORK TABLE DATA AS THE LATEST COPY...*/
insert into ReportsData..CDC_TradeShowRollUpNEW(
	VendorID, ReorderVendorID, ItemCode, Parent, ISBN, ProductType, Buyer, SectionCode, Title, 
	Cost, Price, MSRP, QtyShipped, QtyTrans, QtyDamaged, QtySold, QtyMarkedDown, QtyReturned, 
	QtyRTV, RegisterPrice, ExtendedAmt, OnHand, AmtInvoiced, Reorderable, LastPO, LastReceived, 
	FirstReceived, SchemeID,FOBPO,FOBItem,Publisher,Author,Coupons,CouponAmt,QtyDisc,DiscAmt,
	TXBQty, TXBAmt, OnlineQtySold, SellingPrice)
select
	VendorID
	,ReorderVendorID
	,tsr.ItemCode
	,Parent
	,ISBN
	,ProductType
	,Buyer
	,SectionCode
	,Title
	,Cost
	,Price
	,MSRP
	,QtyShipped
	,QtyTrans
	,QtyDamaged
	,QtySold
	,QtyMarkedDown
	,QtyReturned
	,isnull(br.TotalReturns,0)[TotalReturns]
	,RegisterPrice
	,ExtendedAmt
	,OnHand
	,AmtInvoiced
	,Reorderable
	,LastPO
	,LastReceived
	,FirstReceived
	,SchemeID
	,FOBPO
	,FOBItem
	,Publisher
	,Author
	,Coupons
	,CouponAmt
	,QtyDisc
	,DiscAmt
	,cast(isnull(txb.QUANTITY,0)as int)[TXBQty]
	,cast(isnull(txb.XTNDPRCE,0)as money)[TXBAmt]
	,os.OnlineQtySold
	,os.SellingPrice
from #CDC_TradeShowRollUp tsr 
	left join #BSRtn br on tsr.ItemCode=br.ItemCode
	left join #TXB txb on right('00000000000000000000'+ltrim(rtrim(txb.ITEMNMBR)),20)=tsr.ItemCode
	left join #online_sales os on tsr.ItemCode=os.ItemCode


--------go back and update any missing FOBItems......
if (select COUNT(*)
	from ReportsData..CDC_TradeShowRollUpNEW t 
		inner join ReportsData..OrderDetail od on od.ItemCode=t.ItemCode and od.PONumber=t.LastPO
	where ISNULL(t.FOBItem,'')='' and isnull(od.SpecialInstructions,'')<>'') > 0
	begin
	update t
		set t.FOBItem=cast(od.SpecialInstructions as varchar(250))
		from ReportsData..CDC_TradeShowRollUpNEW t 
			inner join ReportsData..OrderDetail od on od.ItemCode=t.ItemCode and od.PONumber=t.LastPO
			inner join ReportsData..OrderHeader oh on t.LastPO=oh.PONumber	
		where ISNULL(t.FOBItem,'')='' and isnull(od.SpecialInstructions,'')<>''
	end

if (select COUNT(*)
	from ReportsData..CDC_TradeShowRollUpNEW t 
		inner join ReportsData..OrderHeader oh on t.LastPO=oh.PONumber
	where ISNULL(t.FOBPO,'')='' and isnull(oh.SpecInstructions,'')<>'') > 0
	begin
	update t
		set t.FOBPO=cast(oh.SpecInstructions as varchar(250))
		from ReportsData..CDC_TradeShowRollUpNEW t 
			inner join ReportsData..OrderHeader oh on t.LastPO=oh.PONumber		
		where ISNULL(t.FOBPO,'')='' and isnull(oh.SpecInstructions,'')<>''
	end


/*FINAL CLEANOUT*/
drop table CDC_SDV_WORK
drop table CDC_SDV_SalesData
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
go
