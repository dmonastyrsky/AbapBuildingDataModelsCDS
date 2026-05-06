@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'I_CONNECTION_R Test'
@Metadata.ignorePropagatedAnnotations: true
define view entity Z98_R_I_CONNECTION_R
  as select from /DMO/I_Connection_R


{
  key AirlineID,
  key ConnectionID,

      //    _Airline._Currency._Text.CurrencyName

      _Airline._Currency._Text[ Language = 'E' ].CurrencyName,
      _Airline._Currency._Text[ 1: Language = 'E' ].CurrencyName as CurrencyName2
}
where
      AirlineID    = 'AA'
  and ConnectionID = '0017'
