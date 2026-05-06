@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employee (Query)'
@Metadata.ignorePropagatedAnnotations: true
define view entity Z98_C_EmployeeQuery
  as select from Z98_R_Employee
{
  key EmployeeId,
      FirstName,
      LastName,
      BirthDate,
      EntryDate,
      DepartmentId,
      _Department.Description as DepartmentDescription,
      _Department._Assistant.LastName as AssistantName,
      case EmployeeId 
        when _Department.HeadId then 'H'
        when _Department.AssistantId then 'A'
        else ''
      end as EmployeeRole,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      AnnualSalary,
      CurrencyCode,
      /* Associations */
      _Department
}
