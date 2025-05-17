/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

/*
 Everything here is to support the Fish Identifier Cam iOS app.

 We use an API from Fishial.AI for doing fish identification.

 Developer API Overview:
 https://docs.fishial.ai/api

 Developer Portal:
 https://portal.fishial.ai/developers

 Recognizable Specifies List (currently v9, with 639 species, as of 2025-05-16):
 https://docs.fishial.ai/api/specieslist

 Support email: support@fishial.ai

 API Documentation

 Official API documentation is on Github, here:
 https://github.com/fishial/devapi

 This API uses the following endpoints with a base URL of https://api-users.fishial.ai

 POST /v1/auth/token
 Provide `client_id` and `client_secret` to get an `access_token`

 OUTGOING
 Your server (this script) provides your `client_id` and `client_secret`

 Content-Type: application/json
 {
 "client_id": "<our-client-id>",             <-- From the fishial dashboard
 "client_secret": "<our-client-secret>"      <-- Hopefully you savewd this somewhere
 }

 RESPONSE JSON
 {
 "access_token" : "eyJhbGciOiJIUzI1NiJ9.eyJleH<redact>]dULtGhCGe7kpEJEvDzrZCurss",
 "token_type" : "Bearer"
 }


 POST /v1/recognition/upload
 Use `access_token` to request a signed upload URL

 OUTGOING
 Provide your bearer token and some image information

 Accept: application/json
 Authorization: Bearer <your-bearer-token>
 Content-Type: application/json
 {
 "filename": "fishpic.jpg",                     <-- filename
 "content_type": "image/jpeg",                  <-- we identified what kind of image this is - important!
 "byte_size": 2204455,                          <-- data size, in bytes
 "checksum": "EA5w4bPQDfzBgEbes8ZmuQ=="         <-- md5 base64 encoded
 }

 The string value for `checksum` is a base64 encoded md5 hash of the file

 RESPONSE
 {
 "byte-size" : 2204455,                             <-- size of the file - same size we declared above
 "checksum" : "EA5w4bPQDfzBgEbes8ZmuQ==",           <-- this is your base64 encoded md5 hash
 "content-type" : "image/jpeg",
 "created-at" : "2025-05-13T18:46:16.806Z",
 "direct-upload" : {                                <-- details of how to uplaod
 "headers" : {
 "Content-Disposition" : "inline; filename=\"fishpic.jpg\"; filename*=UTF-8''fishpic.jpg",
 "Content-MD5" : "EA5w4bPQDfzBgEbes8ZmuQ=="
 },
 "url" : "https://storage.googleapis.com/backend-fishes-st<redact>]36JNc4%2BRg%3D%3D"
 },
 "filename" : "fishpic.jpg",
 "id" : 9436493,
 "key" : "qrh7v80ud6ptxp06j96mb9u6q1jp",
 "metadata" : {},
 "service-name" : "google",
 "signed-id" : "<your-signed-id>"
 }


 PUT <direct-upload.url>
 Using the URL provided by the response above, upload to the given URL.
 Use the headers exactly as provided.  For Content-Type you need to provide an empty header:

 PUT "https://storage.googleapis.com/backend-fishes-st<redact>]36JNc4%2BRg%3D%3D"
 Content-Type:
 <data is the binary data of the image file>

 GET /v1/recognition/image
 Use to fetch the recgonition result

 OUTGOING REQUEST
 Use your bearer token again and give a single query parameter, which was the `signed-id`
 you were provided above

 GET https://api.fishial.ai/v1/recognition/image?q=<your-signed-id>



 ----------------------------------------------

 Our process:

 1.  On launch, app logs into Firebase as an anonymous user and gets the
 firebase user token and app check token and calls our `login` endpoint

 2.  App determines image content type, data size in bytes, and calculates
 the base64-encoded md5 checksum, calling our firebase function:

 upload_request(), including these parameters:
 file_content_type (String)
 file_size_bytes (Integer)
 file_base64_md5 (String)

 3.  upload_request fetches an auth token via GET /v1/auth/token

 4.  upload_request requests upload details via POST /v1/recognition/upload
 Sends this back to the app:
 Header: Authorization <bearer-token>
 {
 upload_headers: [
 <string : string>
 ],
 upload_url: "<string>"
 signed_id: "<string>"
 }

 5. App uploads the actual image with

 PUT <upload_url>            <-- URL provided in step 4
 <upload_headers>            <-- headers provided in step 4
 Content-Type:               <-- empty header value
 <binary file data>

 6. App requests actual results with call to our 2nd endpoint:

 get_recognition_result() including one parameter

 signed_id

 7.  get_recognition_result() fetches a bearer token and then does the
 request

 GET https://api.fishial.ai/v1/recognition/image?q=<your-signed-id>

 Returning results to the app
 */

// This says it is triggered on https to its endpoint name
const {onRequest} = require("firebase-functions/v2/https");
const {getAuth} = require("firebase-admin/auth");
const { initializeApp } = require('firebase-admin/app');

const logger = require("firebase-functions/logger");
const admin = require('firebase-admin');

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

const adminApp = initializeApp();

// const {functions} = require('firebase-functions/v2');
const {defineSecret} = require('firebase-functions/params')

const fishialClientIDReference = defineSecret("FISHIAL_CLIENT_ID");
const fishialClientSecretReference = defineSecret("FISHIAL_CLIENT_SECRET");

// const { Readable } = require('stream');



// **************************************************************************************
//
//  upload_request
//
//  JSON parameters:
//      "filename": "fishpic.jpg",                     <-- filename
//      "content_type": "image/jpeg",                  <-- we identified what kind of image this is - important!
//      "byte_size": 2204455,                          <-- data size, in bytes
//      "checksum": "EA5w4bPQDfzBgEbes8ZmuQ=="         <-- md5 base64 encoded
// **************************************************************************************

exports.upload_request = onRequest({ secrets: [fishialClientIDReference, fishialClientSecretReference] }, async (req, res) => {
    logger.info("UPLOAD_REQUEST triggered - running checks");

    incrementActivityCounter("upload_requests");

    try {
        const userIdentifier = await verifyFirebaseUserAuthAndAppCheck(req);
        logger.log(`Firebase user auth and App Check verified! -- user ID ${userIdentifier}...`);

        const fishIdentifierCamVersion = req.get('FishIdentifierCam-Version');
        if (fishIdentifierCamVersion.length == 0) {
            logger.error("LOGIN FishIdentifierCam is empty");
            incrementActivityCounter("login_versionCheckFailed");
            res.status(401).send("Unauthorized: Malformed data");
            return;
        }
        logger.log("LOGIN request's FishIdentifierCam-Version header: ", fishIdentifierCamVersion);
        const uid = req.user.uid;
        if (uid.length == 0) {
            logger.error("LOGIN UID is empty");
            incrementActivityCounter("login_uidCheckFailed");
            res.status(401).send("Unauthorized: Malformed data");
            return;
        }
        logger.log("LOGIN request's uid: ", uid);

        // PARSE INPUT PARAMETERES FROM APP
        const json = req.body;

        if (typeof json !== "object" || json === null) {
            logger.error("UPLOAD_REQUEST: body is not valid JSON");
            res.status(400).send("Bad Request: JSON body required");
            return;
        }

        const { filename, content_type, byte_size, checksum } = json;

        if (typeof filename !== "string" || !filename.trim()) {
            logger.error("UPLOAD_REQUEST: Invalid or missing 'filename'");
            res.status(400).send("Bad Request: 'filename' is required and must be a non-empty string");
            return;
        }

        if (typeof content_type !== "string" || !/^image\/[a-z0-9.+-]+$/i.test(content_type)) {
            logger.error("UPLOAD_REQUEST: Invalid or missing 'content_type'");
            res.status(400).send("Bad Request: 'content_type' must be a valid image MIME type");
            return;
        }

        if (typeof byte_size !== "number" || byte_size <= 0 || !Number.isFinite(byte_size)) {
            logger.error("UPLOAD_REQUEST: Invalid or missing 'byte_size'");
            res.status(400).send("Bad Request: 'byte_size' must be a positive number");
            return;
        }

        if (typeof checksum !== "string" || !/^[A-Za-z0-9+/]{22}==$/.test(checksum)) {
            logger.error("UPLOAD_REQUEST: Invalid or missing 'checksum'");
            res.status(400).send("Bad Request: 'checksum' must be a base64-encoded MD5 string");
            return;
        }

        logger.log("UPLOAD_REQUEST JSON validated:", { filename, content_type, byte_size, checksum });



        // Get access token
        /*const fishialAccessToken = */await getFishialAccessToken();
    } catch (error) {
        logger.error("Error verifying Firebase user auth and App Check: ", error);
        incrementActivityCounter("login_authFailed");
        res.status(401).send("Unauthorized: " + error.message);
        return;
    }
});

// **************************************************************************************
//
//  login
//
// **************************************************************************************

exports.login = onRequest(async (req, res) => {
    logger.info("LOGIN triggered - running checks..", {structuredData: true});
    incrementActivityCounter("login_requests");

    try {
        const userIdentifier = await verifyFirebaseUserAuthAndAppCheck(req);
        logger.log(`Firebase user auth and App Check verified! -- login user ID ${userIdentifier}...`);

        // LOGIN SUCCESS - GIVE US SOME RELEVANT STUFF
        logRequestHeaders(req);

        const fishIdentifierCamVersion = req.get('FishIdentifierCam-Version');
        if (fishIdentifierCamVersion.length == 0) {
            logger.error("LOGIN FishIdentifierCam is empty");
            incrementActivityCounter("login_versionCheckFailed");
            res.status(401).send("Unauthorized: Malformed data");
            return;
        }
        logger.log("LOGIN request's FishIdentifierCam-Version header: ", fishIdentifierCamVersion);
        const uid = req.user.uid;
        if (uid.length == 0) {
            logger.error("LOGIN UID is empty");
            incrementActivityCounter("login_uidCheckFailed");
            res.status(401).send("Unauthorized: Malformed data");
            return;
        }
        logger.log("LOGIN request's uid: ", uid);

        const acceptHeader = req.get('accept');
        logger.log("Incoming request's Accept header: ", acceptHeader);

        const contentTypeHeader = req.get('content-type');
        logger.log("Incoming request's Content-Type header: ", contentTypeHeader);

        const data = {
            "login_result": "success",
            messages: [
                       {
                           id: "0x0001",
                           type: "debug",
                           is_one_time: true,
                           app_version: "=1.0(16)",
                           title: "Thank you!",
                           message: "Thank you for using Fishy Identifier Cam",
                           buttons: [
                               {
                                   title: "Cancel",
                                   action_type: "dismiss",
                                   action_data: ""
                               },
                               {
                                   title: "OK",
                                   action_type: "open_url",
                                   action_data: "https://microsoft.com"
                               }
                           ]
                       }
                       ]
        };

        logger.log("Setting content type header");
        res.set('Content-Type', 'application/json');
        logger.log("Sending 200 with data");
        res.status(200).send(JSON.stringify(data));

    } catch (error) {
        logger.error("Error verifying Firebase user auth and App Check: ", error);
        incrementActivityCounter("login_authFailed");
        res.status(401).send("Unauthorized: " + error.message);
        return;
    }

    logger.log("LOGIN FINISHED.");
});


// **************************************************************************************
//
// verifyFirebaseUserAuthAndAppCheck
//
// verifies firebase user authentication token (`idToken`) as well as App Check token
//
// On success, returns a firebase uid (user identifier)
//
// **************************************************************************************
async function verifyFirebaseUserAuthAndAppCheck(req) {
    logger.info("verifyFirebaseUserAuthAndAppCheck", {structuredData: true});
    logger.info(`request.ip = ${req.ip}`);

    const userAgent = req.headers["user-agent"];
    logger.log(`User agent: ${userAgent}`);

    // Verify Firebase Authentication token
    const authHeader = req.header("Authorization");
    logger.log("Authorization header: ", authHeader);
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        logger.log("Authorization header missing or doesn't begin with 'Bearer '");
        logRequestHeaders(req);
        throw new Error("Firebase user authorization failed");
    }

    const idToken = authHeader.split("Bearer ")[1];
    logger.log("ID Token: ", idToken);

    let userIdentifier;

    try {
        const decodedToken = await getAuth(adminApp).verifyIdToken(idToken);
        logger.log("Decoded Token.");
        const uid = decodedToken.uid;
        if (!uid) {
            logger.log("Uid decoded from ID token doesn't exist");
            logRequestHeaders(req);
            logRequestBody(req);
            throw new Error("Firebase uid decoded from ID token doesn't exist");
        }
        logger.log("Firebase uid decoded: ", uid);
        userIdentifier = uid;

        // Token is valid
        req.user = decodedToken; // Add user info to request object
    } catch (error) {
        logger.log("Error decoding token: ", error);
        logRequestHeaders(req);
        logRequestBody(req);
        throw new Error("Firebase user authorization failed");
    }
    logger.log("Firebase user's auth `idToken` verified!");

    // Verify App Check token
    logger.log("Checking for App Check token");
    if (process.env.FUNCTIONS_EMULATOR !== "true") { // Skip App Check verification in emulator
        const appCheckToken = req.header("X-Firebase-AppCheck");
        logger.log("App Check token: ", appCheckToken);
        if (!appCheckToken) {
            logger.log("App Check token missing.");
            logRequestHeaders(req);
            throw new Error("Firebase App Check verification failed");
        }
        try {
            await admin.appCheck().verifyToken(appCheckToken, {consume: true});
            logger.log("App Check token verified!");
        } catch (err) {
            logger.log("App Check verification failed: ", err);
            logRequestHeaders(req);
            logRequestBody(req);
            throw new Error("Firebase App Check verification failed");
        }
    } else {
        logger.log("App Check token not required in emulator - skipped verification");
    }

    logger.log(`uid ${userIdentifier}] Everything is GOOD!  :-)`);
    return userIdentifier;
}



/*

 getFishialAccessToken

 Calls the fishial POST /v1/auth/token endpoint to request an access token.
 Throws on any error or returns the token string.

 */
async function getFishialAccessToken() {
    logger.log("Getting Fishial access token");

    // Fetch our client_id
    const client_id = fishialClientIDReference.value();
    if (!client_id || client_id.length === 0) {
        logger.error("Fishial client id is not set");
        throw new Error("Missing client_id");
    }
    logger.log("Fishial client_id found successfully");

    // Fetch our client_id
    const client_secret = fishialClientSecretReference.value();
    if (!client_secret || client_secret.length === 0) {
        logger.error("Fishial client_secret is not set");
        throw new Error("Missing client_secret");
    }
    logger.log("Fishial client_secret found successfully");


    // Request an access token from Fishial
    const targetUrl = "https://api-users.fishial.ai/v1/auth/token"
    logger.log("Requesting access token from ", targetUrl);
    try {
        const response = await fetch(targetUrl, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                client_id: `${client_id}`,
                client_secret: `${client_secret}`
            })
        });

        logger.log("Awaiting response from ", targetUrl);

        let data;
        try {
            data = await response.json();
        } catch (err) {
            logger.error("/v1/auth/token API response is not JSON: ", err);
            throw new Error("Response is not JSON");
        }
        logger.log("Parsed JSON response: ", data);

        if (data.token_type !== "Bearer") {
            logger.error("Expected Bearer token - got something else");
            throw new Error(`Expected Bearer token, got: ${data.token_type}`);
        }

        const accessToken = data.access_token;
        if (!accessToken || accessToken.length == 0) {
            logger.error("Access token is missing or empty");
            throw new Error("Access token is missing or empty");
        }

        if (typeof accessToken !== "string") {
            logger.error(`Access token is ${typeof accessToken} - expected string`);
            throw new Error("Access token is not a string");
        }
        logger.log("Got access token: ", accessToken);
        return accessToken;

    } catch (error) {
        logger.error("Error getting access token: ", error);
        incrementActivityCounter("getFishialAccessToken_internalServerError");
        throw error;


        //    POST /v1/auth/token
        //    Provide `client_id` and `client_secret` to get an `access_token`
        //
        //    OUTGOING
        //    Your server (this script) provides your `client_id` and `client_secret`
        //
        //    Content-Type: application/json
        //    {
        //        "client_id": "<our-client-id>",             <-- From the fishial dashboard
        //        "client_secret": "<our-client-secret>"      <-- Hopefully you savewd this somewhere
        //    }
        //
        //    RESPONSE JSON
        //    {
        //        "access_token" : "eyJhbGciOiJIUzI1NiJ9.eyJleH<redact>]dULtGhCGe7kpEJEvDzrZCurss",
        //        "token_type" : "Bearer"
        //    }

    }
}

// **************************************************************************************
//
// chat completions endpoint
//
// **************************************************************************************
//exports.chatCompletions = onRequest({ secrets: [ deepseekKeyReference, openAIKeyReference ] }, async (req, res) => {
//    logger.info("CHAT COMPLETIONS triggered", {structuredData: true});
//    incrementActivityCounter("chatCompletions_requests");
//    logRequestBody(req);
//
//    // Make sure we have a valid user
//    try {
//        await verifyFirebaseUserAuthAndAppCheck(req);
//        logger.log("Firebase user auth and App Check verified! -- chat completions continuing...");
//    } catch (error) {
//        logger.error("Error verifying Firebase user auth and App Check: ", error);
//        incrementActivityCounter("chatCompletions_authFail");
//        res.status(401).send("Unauthorized: " + error.message);
//        return;
//    }
//
//    // Validate the incoming request
//    if (req.method !== "POST") {
//        logger.log("Method not allowed", req.method);
//        incrementActivityCounter("chatCompletions_methodNotAllowed");
//        res.status(405).send("Method not allowed");
//        return;
//    }
//
//    // Fetch our Deepseek API key
//    const deepseekKey = deepseekKeyReference.value();
//    if (deepseekKey.length === 0) {
//        logger.error("Deepseek key is not set");
//        incrementActivityCounter("chatCompletions_missingAPIKey");
//        res.status(500).send("Deepseek API key is not set");
//        return;
//    }
//    logger.log("Deepseek API key found successfully");
//
//    const acceptHeader = req.get('accept');
//    logger.log("Incoming request's Accept header: ", acceptHeader);
//
//    const contentTypeHeader = req.get('content-type');
//    logger.log("Incoming request's Content-Type header: ", contentTypeHeader);
//
//
//    const openAIKey = openAIKeyReference.value();
//    let contentAnalysisScore = 0.0;
//    if (openAIKey.length === 0) {
//        logger.log("OpenAI Key not set");
//        contentAnalysisScore = -1.0;
//    } else {
//        logger.log("Successfully fetched OpenAI key. Trying content analysis.");
//        const result = await doContentAnalysis(req, openAIKey);
//
//        // Sum up content analysis results
//        if (result &&
//            typeof result === 'object' &&
//            result.categories &&
//            Array.isArray(result.categories)) {
//            for (const c of result.categories) {
//                if (
//                    c &&
//                    typeof c === 'object' &&
//                    c.flagged === true &&
//                    typeof c.score === 'number' &&
//                    isFinite(c.score)
//                    ) {
//                        contentAnalysisScore += c.score;
//                    }
//            }
//            logger.log("CONTENT ANALYSIS SCORE: ", contentAnalysisScore.toFixed(4));
//            if (contentAnalysisScore > 0.0) {
//                incrementActivityCounter("contentAnalysis_flag");
//                if (contentAnalysisScore > 0.50) {
//                    incrementActivityCounter("contentAnalysis_redFlag");
//                }
//            }
//        } else {
//            logger.error("Couldn't calculate content analysis score due to unexpected object structure");
//            contentAnalysisScore = -1.0;
//            incrementActivityCounter("contentAnalysis_failed");
//        }
//    }
//
//    // Do the actual API request to Deepseek now
//    const targetUrl = "https://api.deepseek.com/v1/chat/completions"
//    logger.log("Chat completions post to ", targetUrl);
//    try {
//        const response = await fetch(targetUrl, {
//            method: "POST",
//            headers: {
//                "Authorization": `Bearer ${deepseekKey}`,
//                "Content-Type": "application/json",
//                "Accept": acceptHeader
//            },
//            body: req.rawBody
//        });
//
//        logger.log("Awaiting response from ", targetUrl);
//
//        // Set response headers to match incoming response
//        res.writeHead(response.status, {
//            'Content-Type': response.headers.get('content-type'),
//            'X-Seekly-Content-Analysis-Score': contentAnalysisScore.toFixed(4)
//        });
//        logger.log("Wrote Content-Type header - piping response");
//        // Pipe the response directly
//        Readable.fromWeb(response.body).pipe(res);
//
//    } catch (error) {
//        logger.error("Chat completions error: ", error);
//        incrementActivityCounter("chatCompletions_internalServerError");
//        res.status(500).send("Internal server error");
//    }
//    logger.log("CHAT COMPLETIONS FINISHED.");
//});
//
//// **************************************************************************************
////
//// models endpoint
////
//// **************************************************************************************
//exports.models = onRequest({ secrets: [ deepseekKeyReference ] }, async (req, res) => {
//    logger.info("MODELS triggered", {structuredData: true});
//    incrementActivityCounter("models_requests");
//
//    // Make sure we have a valid user
//    try {
//        await verifyFirebaseUserAuthAndAppCheck(req);
//        logger.log("Firebase user auth and App Check verified! -- MODELS continuing...");
//    } catch (error) {
//        logger.error("Error verifying Firebase user auth and App Check: ", error);
//        incrementActivityCounter("models_authFailed");
//        res.status(401).send("Unauthorized: " + error.message);
//        return;
//    }
//
//    // Validate the incoming request
//    if (req.method !== "GET") {
//        logger.log("Method not allowed", req.method);
//        incrementActivityCounter("models_methodNotAllowed");
//        res.status(405).send("Method not allowed");
//        return;
//    }
//
//    // Fetch our Deepseek API key
//    const deepseekKey = deepseekKeyReference.value();
//    if (deepseekKey.length === 0) {
//        logger.error("Deepseek key is not set");
//        incrementActivityCounter("models_missingAPIKey");
//        res.status(500).send("Deepseek API key is not set");
//        return;
//    }
//    logger.log("Deepseek API key found successfully");
//
//    // Do the actual API request to Deepseek now
//    const targetUrl = "https://api.deepseek.com/v1/models"
//    logger.log("Fetching models from ", targetUrl);
//    try {
//        const response = await fetch(targetUrl, {
//            method: "GET",
//            headers: {
//                "Authorization": `Bearer ${deepseekKey}`,
//                "Content-Type": "application/json"
//            }
//        });
//
//        logger.log("Awaiting response from ", targetUrl);
//        const data = await response.json();
//        logger.log("Response received from ", targetUrl);
//        res.status(200).json(data);
//    } catch (error) {
//        logger.error("Error fetching models: ", error);
//        incrementActivityCounter("models_internalServerError");
//        res.status(500).send("Internal server error");
//    }
//    logger.log("MODELS FINISHED.");
//});


/******************************
 DEBUG LOGGING HELPER FUNCTIONS
 ******************************/

// Log the request body (as a string)
function logRequestBody(req) {
    let bodyStr;

    if (typeof req.body === 'object' && req.body !== null) {
        try {
            bodyStr = JSON.stringify(req.body);
        } catch (e) {
            logger.warn("Failed to stringify req.body:", e);
            bodyStr = req.rawBody.toString() || '[Unstringifiable body]';
        }
    } else if (typeof req.body === 'string') {
        bodyStr = req.body;
    } else if (Buffer.isBuffer(req.rawBody)) {
        bodyStr = req.rawBody.toString();
    } else {
        bodyStr = '[No body]';
    }

    logger.debug("REQUEST BODY: " + bodyStr);
}

// Log the request headers
function logRequestHeaders(req) {
    for (const [key, value] of Object.entries(req.headers)) {
        logger.log(`  HEADER: ${key}: ${value}`);
    }
}



/*************************
 ADMIN DATABASE OPERATIONS
 *************************/

// Metrics can't be empty and can't contain ".", "#", "$", "[", or "]"
async function incrementActivityCounter(name) {
    logger.log(`COUNTER: Incrementing ${name} _ DISABLVED"`);
    //    try {
    //        const db = admin.database();
    //        await db.ref(`/metrics/${name}`).transaction(n => (n || 0) + 1);
    //    } catch (error) {
    //        logger.error("Error incrementing counter with name " + name + ":", error)
    //    }
}
