/*==> Ref:d:\programmanee\prototype-gpw\notpublish\customprinting\documentcommands\gpw_bom_form.sql ==>*/
 
-- DECLARE @p0 INT = 2

DECLARE @BomId INT = @p0



Select	b.Code BOMCode
		,b.Name BOMName
		,bl.LineCode
		,bl.BOMWBSId WBSId
		,bl.BOMWBSCode WBSCode
		,bw.[Description] WBSName
		,bl.Description
		,bl.Qty BaseLineQty
		,bl.UnitName
		,bl.StandardUnitCost
        ,(bl.Qty * bl.StandardUnitCost) BaseLineAmount
        ,bl.Remarks
From BOMs b 
Left Join BOMFormulaLines bl ON bl.BOMId = b.Id
INNER JOIN BOMWBS bw ON bl.BOMWBSId = bw.Id
Where b.Id = @BomId