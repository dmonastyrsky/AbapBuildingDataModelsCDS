extend view entity Z98_C_EmployeeQueryP with 
association to I_Country as _ZZCountryZem on $projection.ZZCountryZem = _ZZCountryZem.Country
{
    Employee.ZZTitleZem as ZZTitleZem,
    Employee.ZZCountryZem as ZZCountryZem,
    @EndUserText.label: 'Full Name'
    concat_with_space( Employee.FirstName, Employee.LastName, 1 ) as ZZFullNameZem,
    _ZZCountryZem.IsEuropeanUnionMember     as ZZEUBasedZem
}
