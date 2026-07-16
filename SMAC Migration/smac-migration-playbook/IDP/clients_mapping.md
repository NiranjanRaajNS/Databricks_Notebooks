# Table Mapping: Clients → clients

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: Clients (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: clients (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | id | integer | Use legacy Id if available, otherwise generate | IDENTITY column |
| ClientId | varchar | client_id | varchar | TRIM(ClientId) | Business key |
| Enabled | boolean | enabled | boolean | COALESCE(Enabled, false) | Direct copy |
| ProtocolType | varchar | protocol_type | varchar | TRIM(ProtocolType) | Direct copy |
| RequireClientSecret | boolean | require_client_secret | boolean | COALESCE(RequireClientSecret, true) | Direct copy |
| ClientName | varchar | client_name | varchar | TRIM(ClientName) | Direct copy |
| Description | varchar | description | varchar | TRIM(Description) | Direct copy |
| ClientUri | varchar | client_uri | varchar | TRIM(ClientUri) | Direct copy |
| LogoUri | varchar | logo_uri | varchar | TRIM(LogoUri) | Direct copy |
| RequireConsent | boolean | require_consent | boolean | COALESCE(RequireConsent, false) | Direct copy |
| AllowRememberConsent | boolean | allow_remember_consent | boolean | COALESCE(AllowRememberConsent, true) | Direct copy |
| AlwaysIncludeUserClaimsInIdToken | boolean | always_include_user_claims_in_id_token | boolean | COALESCE(AlwaysIncludeUserClaimsInIdToken, false) | Direct copy |
| RequirePkce | boolean | require_pkce | boolean | COALESCE(RequirePkce, false) | Direct copy |
| AllowPlainTextPkce | boolean | allow_plain_text_pkce | boolean | COALESCE(AllowPlainTextPkce, false) | Direct copy |
| RequireRequestObject | boolean | require_request_object | boolean | COALESCE(RequireRequestObject, false) | Direct copy |
| AllowAccessTokenViaBrowser | boolean | allow_access_token_via_browser | boolean | COALESCE(AllowAccessTokenViaBrowser, false) | Direct copy |
| FrontChannelLogoutUri | varchar | front_channel_logout_uri | varchar | TRIM(FrontChannelLogoutUri) | Direct copy |
| FrontChannelLogoutSessionRequired | boolean | front_channel_logout_session_required | boolean | COALESCE(FrontChannelLogoutSessionRequired, false) | Direct copy |
| BackChannelLogoutUri | varchar | back_channel_logout_uri | varchar | TRIM(BackChannelLogoutUri) | Direct copy |
| BackChannelLogoutSessionRequired | boolean | back_channel_logout_session_required | boolean | COALESCE(BackChannelLogoutSessionRequired, false) | Direct copy |
| AllowOfflineAccess | boolean | allow_offline_access | boolean | COALESCE(AllowOfflineAccess, false) | Direct copy |
| IdentityTokenLifetime | integer | identity_token_lifetime | integer | Direct copy | Direct copy |
| AccessTokenLifetime | integer | access_token_lifetime | integer | Direct copy | Direct copy |
| AuthorizationCodeLifetime | integer | authorization_code_lifetime | integer | Direct copy | Direct copy |
| ConsentLifetime | integer | consent_lifetime | integer | Direct copy | Direct copy |
| AbsoluteRefreshTokenLifetime | integer | absolute_refresh_token_lifetime | integer | Direct copy | Direct copy |
| SlidingRefreshTokenLifetime | integer | sliding_refresh_token_lifetime | integer | Direct copy | Direct copy |
| RefreshTokenUsage | integer | refresh_token_usage | integer | Direct copy | Direct copy |
| UpdateAccessTokenClaimsOnRefresh | boolean | update_access_token_claims_on_refresh | boolean | COALESCE(UpdateAccessTokenClaimsOnRefresh, false) | Direct copy |
| RefreshTokenExpiration | integer | refresh_token_expiration | integer | Direct copy | Direct copy |
| AccessTokenType | integer | access_token_type | integer | Direct copy | Direct copy |
| EnableLocalLogin | boolean | enable_local_login | boolean | COALESCE(EnableLocalLogin, true) | Direct copy |
| IncludeJwtId | boolean | include_jwt_id | boolean | COALESCE(IncludeJwtId, false) | Direct copy |
| AlwaysSendClientClaims | boolean | always_send_client_claims | boolean | COALESCE(AlwaysSendClientClaims, false) | Direct copy |
| ClientClaimsPrefix | varchar | client_claims_prefix | varchar | TRIM(ClientClaimsPrefix) | Direct copy |
| PairWiseSubjectSalt | varchar | pair_wise_subject_salt | varchar | TRIM(PairWiseSubjectSalt) | Direct copy |
| UserSsoLifetime | integer | user_sso_lifetime | integer | Direct copy | Direct copy |
| UserCodeType | varchar | user_code_type | varchar | TRIM(UserCodeType) | Direct copy |
| DeviceCodeLifetime | integer | device_code_lifetime | integer | Direct copy | Direct copy |
| CoordinateLifetimeWithUserSession | boolean | coordinate_lifetime_with_user_session | boolean | COALESCE(CoordinateLifetimeWithUserSession, false) | Direct copy |
| Created | timestamp | created | timestamptz | Created AT TIME ZONE 'UTC' | Timezone conversion |
| Updated | timestamp | updated | timestamptz | Updated AT TIME ZONE 'UTC' | Timezone conversion |
| LastAccessed | timestamp | last_accessed | timestamptz | LastAccessed AT TIME ZONE 'UTC' | Timezone conversion |
| NonEditable | boolean | non_editable | boolean | COALESCE(NonEditable, false) | Direct copy |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- None (master table for clients)

### Dependents (migrate after this table)
- **client_secrets** - references clients.id
- **client_scopes** - references clients.id
- **client_redirect_uris** - references clients.id
- **client_properties** - references clients.id
- **client_post_logout_redirect_uris** - references clients.id
- **client_idp_restrictions** - references clients.id
- **client_grant_types** - references clients.id
- **client_cors_origins** - references clients.id
- **client_claims** - references clients.id

## Data Transformation Rules
- Use legacy integer ID if available, otherwise let database generate via IDENTITY
- Filter out records where ClientId is NULL or empty
- Map timestamps from timestamp without time zone to timestamp with time zone using AT TIME ZONE 'UTC'

