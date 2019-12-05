console.log('Loading event');
var aws = require('aws-sdk');
var ddb = new aws.DynamoDB({
    params: {
        TableName: 'snslambda'
    }
});
var ses = new aws.SES({
    region: 'us-east-1'
});

exports.sendEmail = function (event, context) {
    var SnsMessageId = event.Records[0].Sns.MessageId;
    var SnsPublishTime = event.Records[0].Sns.Timestamp;
    var SnsTopicArn = event.Records[0].Sns.TopicArn;
    var dt = new Date();
    dt.setMinutes(dt.getMinutes() + 30);
    var ExpTime = Math.floor((dt.getTime() - dt.getMilliseconds()) / 1000) + '';
    var Message = event.Records[0].Sns.Message;
    var Username = event.Records[0].Sns.MessageAttributes.Username.Value;
    var Urls = event.Records[0].Sns.MessageAttributes.Urls.Value;
    var Token = event.Records[0].Sns.MessageAttributes.Token.Value;
    var itemParams = {
        Item: {
            Username: {
                S: Username
            },
            Token: {
                S: Token
            },
            ttl: {
                N: ExpTime
            }
        }
    };
    var searchParams = {
        Key: {
            Username: {
                S: Username
            }
        }
    };
    ddb.getItem(searchParams, function (err, data) {
        if (err) console.log(err, err.stack); // an error occurred
        else {
            // successful response
            console.log("Item:" + data.Item);
            if (data.Item === undefined) {
                //Not exist,put Item
                console.log("\nPut Item: " + itemParams.Item.ttl.N);

                ddb.putItem(itemParams, function (err, data) {
                    if (err) console.log(err, err.stack); // an error occurred
                    else {

                        var params = {
                            Destination: {
                                ToAddresses: [Username]
                            },
                            Message: {
                                Body: {
                                    Text: {
                                        Data: Urls
                                    }
                                },
                                Subject: {
                                    Data: "My recipes endpoint"
                                }
                            },
                            Source: "sns@dev.yixie.me"
                        };

                        ses.sendEmail(params, function(err, data) {
                           if (err) console.log("Error:"+err.stack); // an error occurred
                           else     console.log("Data:"+data);           // successful response
                         });
                    }
                });
            } else {
                console.log("\nFind Item:" + data.Item);
            }
        }
    });
};