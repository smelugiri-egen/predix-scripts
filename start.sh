#!/usr/bin/env bash

cat << EOF

Please set the following variables to do this:

1) Predix API endpoint, which is your Cloud Foundry host domain name.

Right now there are two main endpoints:
A) Predix Basic Account : api.system.aws-usw02-pr.ice.predix.io
B) Predix Select Account : api.system.asv-pr.ice.predix.io

For this tutorial, we are assuming you are using a Predix Basic Account.

Therefore, we are setting your API endpoint to "api.system.aws-usw02-pr.ice.predix.io"

EOF

A=api.system.aws-usw02-pr.ice.predix.io
B=api.system.asv-pr.ice.predix.io

CF_HOST=$A

cat << EOF

2) Predix Username

"my.predix.account.email@myorg.com"

TYPE your Predix username in the above format followed by ENTER

EOF

read CF_USERNAME

cat << EOF

3) Predix Password

Now TYPE your Predix password followed by ENTER. Do not worry, we are not storing this.
EOF

read -s CF_PASSWORD

cat << EOF

4) Predix Organization, which is your Cloud Foundry Organization.

For this tutorial, we are assuming you are using a Predix Basic Account.

Therefore, we are setting your organization to the default "$CF_USERNAME"

Press any key when you are ready to proceed...

EOF

CF_ORG=$CF_USERNAME

read -n 1 -s

cat << EOF

5) Predix Space, which is your Cloud Foundry Space.

Now TYPE the SPACE name you want to create. You can choose dev, but we suggest to keep this SPACE name unique
EOF

read CF_SPACE

cat << EOF

Now that we have your variables set, it is time to execute the Predix Login command.

You will notice that Cloud Foundry terminal commands all start with "cf", which stands for Cloud Foundry.  Predix
uses Cloud Foundry to develope, manage and host Predix Microservices in our cloud.

cf login -a $CF_HOST -u $CF_USERNAME -p <hidden> -o $CF_ORG -s $CF_SPACE --skip-ssl-validation

EOF

cf login -a $CF_HOST -u $CF_USERNAME -p $CF_PASSWORD -o $CF_ORG -s $CF_SPACE --skip-ssl-validation

cat << EOF

Congrats, You are logged in!!
Assuming you have set your custom changes in variables.sh and readargs.sh,
Running bash/quickstart.sh to create the services (default: uaa, time-series and asset services) you selected....

EOF

./bash/quickstart.sh

cat << EOF

Default services are created. Below are the services

EOF

cf services

cat << EOF

Press any key to quit...

EOF

read -n 1 -s