const fs = require("fs");
const path = require("path");

const generateLambda = (headers) =>
  `
  exports.handler = async (event, context) => {
    const request = event.Records[0].cf.request;
    const response = event.Records[0].cf.response;
    const headers = response.headers;
    const uri = request.uri;
  
    if (uri.includes("login") || uri.includes("logout")) {
      response.status = 200;
      response.statusDescription = "OK";
      response.body = \`<html><body><p>This is not a real route. If you are seeing this, you most likely are accessing the custom application
      directly from the hosted domain. Instead, you need to access the custom application from within the Merchant Center
      domain, as custom applications are served behind a proxy router.
      To do so, you need to first register the custom application in Merchant Center > Settings > Custom Applications.</p></body></html>\`;
      return response;
    }
  
    if (headers) {
      ${headers.join("\n\t")};
    }
  
    return response;
  };
  
  `;

// This transformer will generate a `lambda.js` config file, based on the application
// environment config and custom headers.
module.exports = ({ headers }) => {
  const setHeaders = Object.entries({
    ...headers,
    "Cache-Control": "no-cache",
  }).map(
    ([key, value]) =>
      `headers["${key.toLowerCase()}"] = [{key: "${key}", value: "${value}"}];`
  );

  fs.writeFileSync(
    path.join(__dirname, "../lambda-edge-headers.js"),
    generateLambda(setHeaders),
    {
      encoding: "utf8",
    }
  );
};
