@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Department (Query)'
@Metadata.ignorePropagatedAnnotations: true
define view entity Z98_C_DepartmentQuery 
  with parameters
    p_target_curr : /dmo/currency_code,
    @EndUserText.label: 'Date of evaluation'
    @Environment.systemField: #SYSTEM_DATE
    p_date        : abap.dats
  as select from Z98_C_EmployeeQueryP( /*Z98_C_EmployeeQuery*/
                   p_target_curr: $parameters.p_target_curr,
                   p_date: $parameters.p_date ) as e
                   right outer join Z98_R_Department as d
                   on e.DepartmentId = d.Id
{
  d.Id,
  d.Description,
  avg( e.CompanyAffiliation as abap.dec(11,1) ) as AverageAffiliation,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  sum( e.AnnualSalary )                         as TotalSalary,
  e.CurrencyCode
}
group by
  d.Id,
  d.Description,
  e.CurrencyCode
