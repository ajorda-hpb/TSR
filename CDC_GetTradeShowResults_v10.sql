-- SP: CDC_GetTradeShowResults_v10
set ANSI_NULLS on
go
set QUOTED_IDENTIFIER on
go

-- =============================================
-- Author:		Joey B
-- Create date: 9/9/2011
-- Description:	Return data for 'Big Pig'.  Used to filter out old data.
-- Change: Split sp into two for different versions.... Replaces previous versions of TradeShow
--	   : 2/15/2012 : Added MSRP to results for TSR. : Joey B.
--	   : 2/21/2018 : Added Online Quantity and Selling Price: Trey G.


-- =============================================
create procedure [dbo].[CDC_GetTradeShowResults_v10]
as
begin
    set NOCOUNT on;
    --excel version return all rows......

    select
        u.ISBN
        ,u.VendorID
        ,u.ReorderVendorid
        ,cast(u.PctSold as decimal(12,2))as PctSold
        ,u.Reorderable
        ,case when (u.QtySold*u.Price)=0 then 0 else cast((u.RegisterPrice/(u.QtySold*u.Price))as decimal(12,2)) end [DiscountPct]
        ,(convert(varchar(10),u.FirstReceived,120)) as FirstReceived
        ,(convert(varchar(10),u.LastReceived,120)) as LastReceived
        ,u.Parent
        ,case 
            when (case -- to temporarily prop up the assortment items....Joey B
                    when right(u.ItemCode,8) > '19999999' then 'Assort' -- 'Assortments to Titles'
                    else case 
                            when ISNULL(u.buyer,'')='' then substring(ltrim(b.BuyerID),1,1) + '.' + substring(b.BuyerID,charindex(' ', b.BuyerID)+1,1) + '.'  
                            else substring(ltrim(u.Buyer),1,1) + '.' + substring(u.buyer,charindex(' ', u.buyer)+1,1) + '.' 
                            end 
                    end)='..' then '' 
            else case -- to temporarily prop up the assortment items....Joey B
		            when right(u.ItemCode,8) > '19999999' then 'Assort' -- 'Assortments to Titles'
		            else case 
                            when ISNULL(u.buyer,'')='' then substring(ltrim(b.BuyerID),1,1) + '.' + substring(b.BuyerID,charindex(' ', b.BuyerID)+1,1) + '.'  
			                else substring(ltrim(u.Buyer),1,1) + '.' + substring(u.buyer,charindex(' ', u.buyer)+1,1) + '.' 
                            end
	                end 
            end as Buyer
        ,u.SectionCode
        ,u.Title
        ,u.Cost
        ,u.Price
        ,u.MSRP
        ,isnull(u.QtyShipped,0) as QtyShipped
        ,isnull(u.QtyTrans,0) as QtyTrans
        ,isnull(u.QtyDamaged,0) as QtyDamaged
        ,isnull(u.QtySold,0) as QtySold
        ,isnull(u.QtyMarkedDown,0) as QtyMarkedDown
        ,isnull(u.QtyReturned,0) as QtyReturned
        ,isnull(u.QTYRTV,0) as QTYRTV
        ,u.RegisterPrice
        ,u.QtySold*u.Price[ExtendedAmt]
        ,u.OnHand
        ,u.AmtInvoiced
        ,u.LastPO
        ,u.ProductType
        ,u.SchemeID
        ,right(u.ItemCode,8)[ItemCode]
        ,ISNULL(cast(w.AvailableQty as varchar(10)),'')[TTBInv]
        ,isnull(u.FOBPO,'')[FOBPO]
        ,isnull(u.FOBItem,'')[FOBItem]
        ,isnull(u.Publisher,'')[Publisher]
        ,isnull(u.Author,'')[Author]
        ,isnull(u.Coupons,0) as Coupons
        ,isnull(u.CouponAmt,0) as CouponAmt
        ,isnull(u.QtyDisc,0) as QtyDisc
        ,isnull(u.DiscAmt,0) as DiscAmt
        ,isnull(u.TXBQty,0) as TXBQty
        ,isnull(u.TXBAmt,0) as TXBAmt
	    ,OnlineQtySold
        ,SellingPrice
    from
        ReportsData..CDC_TradeShowRollUpNEW u --left outer join ReportsData..OrderHeader oh on u.LastPO=oh.PONumber
        left outer join ReportsData..Buyers b on b.Name=u.Buyer
        left outer join rILS_DATA..WMSAvailableQty w on w.ItemCode=u.ItemCode and w.Company='TTB'
    where (right(u.ItemCode,8) > '19999999' 
            and (u.QtyShipped > 19) 
            and (u.FirstReceived>'1/1/2010' 
                    or u.LastReceived>'1/1/2010' 
                    or PctSold<50
                    or (case 
                            when (u.QtySold*u.Price)=0 then 0 
                            else cast((u.RegisterPrice/(u.QtySold*u.Price))as decimal(12,2))
                            end - 100)>=25))
        or ((right(u.ItemCode,8) < '19999999') 
            and (u.FirstReceived>'1/1/2010' 
                    or u.LastReceived>'1/1/2010' 
                    or PctSold<50
                    or (case 
                            when (u.QtySold*u.Price)=0 then 0 
                            else cast((u.RegisterPrice/(u.QtySold*u.Price))as decimal(12,2))
                            end - 100)>=25))
    order by u.LastReceived desc
        ,u.PctSold desc

end



go
