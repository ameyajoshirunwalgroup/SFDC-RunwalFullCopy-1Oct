public class Lockated_FCM_Token_Service {

    // Named Credential API Name for Google's token endpoint
    private static final String GOOGLE_NAMED_CREDENTIAL = 'callout:Google_OAuth2_Token';
    private static String accessToken; // Cache the token

    public static String getAccessToken() {
        if (accessToken != null) {
            return accessToken; // Return cached token if available
        }
        
        // Get the JWT assertion from our generator class
        String jwtAssertion = Lockated_FCM_JWT_Generator.getJWTAssertion();

        HttpRequest req = new HttpRequest();
        req.setEndpoint(GOOGLE_NAMED_CREDENTIAL + '/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String body = 'grant_type=' + EncodingUtil.urlEncode('urn:ietf:params:oauth:grant-type:jwt-bearer', 'UTF-8') + 
                      '&assertion=' + EncodingUtil.urlEncode(jwtAssertion, 'UTF-8');
        req.setBody(body);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                accessToken = (String) responseMap.get('access_token');
                return accessToken;
            } else {
                System.debug('Error getting access token: ' + res.getBody());
                throw new CalloutException('Failed to retrieve access token: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('An error occurred during token exchange: ' + e.getMessage());
            throw e;
        }
    }
}