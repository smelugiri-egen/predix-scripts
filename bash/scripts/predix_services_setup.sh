#!/bin/bash
set -e
rootDir=$quickstartRootDir
logDir="$rootDir/log"

# Predix Dev Bootstrap Script
# Authors: GE SDLP 2015
#
# Welcome new Predix Developers! Run this script to instantiate the following Predix
# services: Timeseries, Asset, and UAA. The script will also configure each service with
# the necessary authorities and scopes, create a UAA user, create UAA client id, and
# post sample data to the Asset service
#

source "$rootDir/bash/scripts/predix_funcs.sh"
source "$rootDir/bash/scripts/variables.sh"
source "$rootDir/bash/scripts/error_handling_funcs.sh"
source "$rootDir/bash/scripts/files_helper_funcs.sh"
source "$rootDir/bash/scripts/curl_helper_funcs.sh"

if ! [ -d "$logDir" ]; then
	mkdir "$logDir"
	chmod 744 "$logDir"
fi
touch "$logDir/quickstart.log"

# Trap ctrlc and exit if encountered
trap "trap_ctrlc" 2
#__append_new_head_log "Creating Predix Services" "#" "$logDir"

function pushAnAppForBinding()
{
	__append_new_head_log "Pushing an app to bind to Predix Services..." "-" "$logDir"

	# Push a test app to get VCAP information for the Predix Services
	getGitRepo "Predix-HelloWorld-WebApp"
	cd Predix-HelloWorld-WebApp

	if __echo_run px push $1 --random-route; then
		__append_new_line_log "App \"$1\" successfully pushed to CloudFoundry!" "$logDir"
	else
		if __echo_run px push $1 --random-route; then
			__append_new_line_log "App \"$1\" successfully pushed to CloudFoundry!" "$logDir"
		else
			__error_exit "There was an error pushing the app \"$1\" to CloudFoundry..." "$logDir"
		fi
	fi
}

function createUaa()
{
	__append_new_head_log "Create UAA Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
		 __try_delete_service $UAA_INSTANCE_NAME
	fi

	if [[ $USE_TRAINING_UAA == 1 ]]; then
		configParameters="{\"adminClientSecret\":\"$UAA_ADMIN_SECRET\"}"
		__try_create_service_using_cfcli $UAA_SERVICE_NAME $UAA_PLAN $UAA_INSTANCE_NAME $configParameters "Predix UAA"
	else
		# Create instance of Predix UAA Service
		__try_create_uaa $UAA_SERVICE_NAME $UAA_PLAN $UAA_INSTANCE_NAME $UAA_ADMIN_SECRET "Predix UAA"
	fi

	# Bind Temp App to UAA instance
	if [[ $BINDING_APP == 1 ]]; then
		__try_bind $1 $UAA_INSTANCE_NAME
	fi

}

function createTimeseries()
{
	__append_new_head_log "Create Time Series Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $TIMESERIES_INSTANCE_NAME
	fi

	if [[ "$TRUSTED_ISSUER_ID" == "" ]]; then
	  getTrustedIssuerIdFromInstance $UAA_INSTANCE_NAME
  fi

	if [[ $USE_TRAINING_UAA == 1 ]]; then
		configParameters="{\"trustedIssuerIds\":[\"$TRUSTED_ISSUER_ID\"]}"
		__try_create_service_using_cfcli $TIMESERIES_SERVICE_NAME $TIMESERIES_SERVICE_PLAN $TIMESERIES_INSTANCE_NAME $configParameters "Predix Timeseries"
	else
		# Create instance of Predix TimeSeries Service
		__try_create_predix_service $TIMESERIES_SERVICE_NAME $TIMESERIES_SERVICE_PLAN $TIMESERIES_INSTANCE_NAME $UAA_INSTANCE_NAME $UAA_ADMIN_SECRET $UAA_CLIENTID_GENERIC $UAA_CLIENTID_GENERIC_SECRET "Predix TimeSeries"
	fi

	if [[ ( $BINDING_APP == 1 ) ]]; then
		# Bind Temp App to TimeSeries Instance
		__try_bind $1 $TIMESERIES_INSTANCE_NAME
	else
	  # set all the timeseries zone urls
	  getTimeseriesZoneIdFromInstance $TIMESERIES_INSTANCE_NAME
	  getTimeseriesIngestUriFromInstance $TIMESERIES_INSTANCE_NAME
	  getTimeseriesQueryUriFromInstance $TIMESERIES_INSTANCE_NAME
	 fi

}

function createACSService() {
	__append_new_head_log "Create Access Control Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $ACCESS_CONTROL_SERVICE_INSTANCE_NAME
	fi

	if [[ "$TRUSTED_ISSUER_ID" == "" ]]; then
		getTrustedIssuerIdFromInstance $UAA_INSTANCE_NAME
	fi

	if [[ $USE_TRAINING_UAA == 1 ]]; then
		configParameters="{\"trustedIssuerIds\":[\"$TRUSTED_ISSUER_ID\"]}"
		__try_create_service_using_cfcli $ACCESS_CONTROL_SERVICE_NAME $ACCESS_CONTROL_SERVICE_PLAN $ACCESS_CONTROL_INSTANCE_NAME $configParameters "Predix Access Control Service"
	else
		# Create instance of Predix Access Control Service
		__try_create_predix_service $ACCESS_CONTROL_SERVICE_NAME $ACCESS_CONTROL_SERVICE_PLAN $ACCESS_CONTROL_SERVICE_INSTANCE_NAME $UAA_INSTANCE_NAME $UAA_ADMIN_SECRET $UAA_CLIENTID_GENERIC $UAA_CLIENTID_GENERIC_SECRET "Predix Access Control Service"
	fi

	# Bind Temp App to ACS Instance
	__try_bind $1 $ACCESS_CONTROL_SERVICE_INSTANCE_NAME

}

function createAssetService() {
	__append_new_head_log "Create Asset Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $ASSET_INSTANCE_NAME
	fi

	if [[ "$TRUSTED_ISSUER_ID" == "" ]]; then
		if [[ ( $BINDING_APP == 0 ) ]]; then
			getTrustedIssuerIdFromInstance $UAA_INSTANCE_NAME
		else
			getTrustedIssuerIdFromInstance $UAA_INSTANCE_NAME
		fi

  	fi

	if [[ $USE_TRAINING_UAA == 1 ]]; then
		configParameters="{\"trustedIssuerIds\":[\"$TRUSTED_ISSUER_ID\"]}"
		__try_create_service_using_cfcli $ASSET_SERVICE_NAME $ASSET_SERVICE_PLAN $ASSET_INSTANCE_NAME $configParameters "Predix Asset Service"
	else
		# Create instance of Predix Asset Service
		__try_create_predix_service $ASSET_SERVICE_NAME $ASSET_SERVICE_PLAN $ASSET_INSTANCE_NAME $UAA_INSTANCE_NAME $UAA_ADMIN_SECRET $UAA_CLIENTID_GENERIC $UAA_CLIENTID_GENERIC_SECRET "Predix Asset"
	fi

	if [[ ( $BINDING_APP == 1 ) ]]; then
	 # Bind Temp App to Asset Instance
		__try_bind $1 $ASSET_INSTANCE_NAME
	fi

	# Get the Zone ID from the environment variables (for use when querying Asset data)
	if [[ ( $BINDING_APP == 0 ) ]]; then
		if [[ "$ASSET_ZONE_ID" == "" ]]; then
			getAssetZoneIdFromInstance $ASSET_INSTANCE_NAME
		fi
		if [[ "$ASSET_URI" == "" ]]; then
			getAssetUriFromInstance $ASSET_INSTANCE_NAME
		fi
	else
		if [[ "$ASSET_ZONE_ID" == "" ]]; then
			getAssetZoneIdFromInstance $ASSET_INSTANCE_NAME
		fi
		if [[ "$ASSET_URI" == "" ]]; then
			getAssetUriFromInstance $ASSET_INSTANCE_NAME
		fi

	fi
}
function createBlobstoreService() {
	__append_new_head_log "Create Blobstore Service Instance" "-" "$logDir"
	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $BLOBSTORE_INSTANCE_NAME
	fi
	if __service_exists $BLOBSTORE_INSTANCE_NAME ; then
		echo "Service $BLOBSTORE_INSTANCE_NAME already exists" # Do nothing
	else
		px cs $BLOBSTORE_SERVICE_NAME $BLOBSTORE_SERVICE_PLAN $BLOBSTORE_INSTANCE_NAME
	fi
	## Deploy the Blobstore sdk
	cd $rootDir
	getRepoURL "predix-blobstore-sdk" blobstore_git_url ../version.json

	getRepoVersion "predix-blobstore-sdk" blobstore_version ../version.json
	echo "git repo version : $blobstore_version"
	rm -rf blobstore-samples
	__echo_run git clone $blobstore_git_url -b $blobstore_version

	cd blobstore-samples/blobstore-aws-sample
	mvn clean install -B -s $MAVEN_SETTINGS_FILE
	cp manifest.yml manifest_temp.yml
	__find_and_replace_string "<my-blobstore-instance>" "$BLOBSTORE_INSTANCE_NAME" "manifest_temp.yml" "$logDir" "manifest_temp.yml"

	px push $INSTANCE_PREPENDER-blobstore-sdk-app -f manifest_temp.yml
	cd $rootDir
	# Automagically open the application in browser, based on OS
  if [[ $SKIP_BROWSER == 0 ]]; then
    getUrlForAppName $INSTANCE_PREPENDER-blobstore-sdk-app apphost "https"
    case "$(uname -s)" in
       Darwin)
         # OSX
         open $apphost
         ;;

       CYGWIN*|MINGW32*|MINGW64*|MSYS*)
         # Windows
         start "" $apphost
         ;;
    esac
	fi
}
function createEventHubService() {
	__append_new_head_log "Create Event Hub Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $EVENTHUB_INSTANCE_NAME
	fi

	if [[ "$TRUSTED_ISSUER_ID" == "" ]]; then
    getTrustedIssuerIdFromInstance $UAA_INSTANCE_NAME
  fi

	if [[ $USE_TRAINING_UAA == 1 ]]; then
		configParameters="{\"trustedIssuerIds\":[\"$TRUSTED_ISSUER_ID\"]}"
		__try_create_service_using_cfcli $EVENTHUB_SERVICE_NAME $EVENTHUB_SERVICE_PLAN $EVENTHUB_INSTANCE_NAME $configParameters "Predix EventHub Service"
	else
		# Create instance of Predix Asset Service
		#__try_create_predix_service $EVENTHUB_SERVICE_NAME $EVENTHUB_SERVICE_PLAN $EVENTHUB_INSTANCE_NAME $UAA_INSTANCE_NAME $UAA_ADMIN_SECRET "$UAA_CLIENTID_GENERIC" $UAA_CLIENTID_GENERIC_SECRET "Event Hub Service"
		#px uaa login $UAA_INSTANCE_NAME admin --secret $UAA_ADMIN_SECRET
		if __service_exists $EVENTHUB_INSTANCE_NAME ; then
	    echo "Service $EVENTHUB_INSTANCE_NAME already exists" # Do nothing
	  else
			px cs $EVENTHUB_SERVICE_NAME $EVENTHUB_SERVICE_PLAN $EVENTHUB_INSTANCE_NAME $UAA_INSTANCE_NAME --admin-secret $UAA_ADMIN_SECRET --publish-client-id "$UAA_CLIENTID_GENERIC" --publish-client-secret "$UAA_CLIENTID_GENERIC_SECRET" --subscribe-client-id "$UAA_CLIENTID_GENERIC" --subscribe-client-secret "$UAA_CLIENTID_GENERIC_SECRET"
		fi
		#configParameters="{\"trustedIssuerIds\":[\"$TRUSTED_ISSUER_ID\"]}"
		#__try_create_service_using_cfcli $EVENTHUB_SERVICE_NAME $EVENTHUB_SERVICE_PLAN $EVENTHUB_INSTANCE_NAME $configParameters "Predix EventHub Service"
	fi

	# Bind Temp App to Asset Instance
	__try_bind $1 $EVENTHUB_INSTANCE_NAME

	getEventHubIngestUri $1
	getEventHubZoneId $1
}

function createMobileService() {
	__append_new_head_log "Create Mobile Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $MOBILE_INSTANCE_NAME
	fi

	getMobileZoneIdFromInstance $MOBILE_INSTANCE_NAME

	__try_create_predix_mobile_service $MOBILE_SERVICE_NAME $MOBILE_SERVICE_PLAN $MOBILE_INSTANCE_NAME $UAA_INSTANCE_NAME $UAA_ADMIN_SECRET  $UAA_USER_NAME $UAA_USER_EMAIL $UAA_USER_PASSWORD "Predix Mobile"

}

function createMobileReferenceApp() {
	__append_new_head_log "Create Mobile Reference App Instance" "-" "$logDir"

    echo "*********************  inside  createMobileReferenceApp *********************** "
	echo $MOBILE_INSTANCE_NAME
	API_GATEWAY_SHORT_ROUTE=`px si $MOBILE_INSTANCE_NAME | grep api_gateway_short_route | sed 's/.*\(https.*\)",/\1/'`
    echo $API_GATEWAY_SHORT_ROUTE
	__append_new_head_log "API_GATEWAY_SHORT_ROUTE: $API_GATEWAY_SHORT_ROUTE" "-" "$logDir"


	echo pm api $API_GATEWAY_SHORT_ROUTE
	__append_new_head_log "Running pm api $API_GATEWAY_SHORT_ROUTE" "-" "$logDir"
	pm api $API_GATEWAY_SHORT_ROUTE

	echo pm auth $UAA_USER_NAME $UAA_USER_PASSWORD
	__append_new_head_log "Running pm auth $UAA_USER_NAME $UAA_USER_PASSWORD" "-" "$logDir"
	pm auth $UAA_USER_NAME $UAA_USER_PASSWORD

	cd ..
	__append_new_head_log "Creating mobile workspace" "-" "$logDir"
	mkdir -p mobile_workspace
	cd mobile_workspace
	MOBILE_WORKSPACE="$( pwd )"
	pm workspace --create

	__append_new_head_log "Building and publishing webapp" "-" "$logDir"
	cd webapps
	rm -rf MobileExample-WebApp-Sample
	git clone https://github.com/PredixDev/MobileExample-WebApp-Sample.git
	cd MobileExample-WebApp-Sample
	npm install
	npm run build
	pm publish


	__append_new_head_log "Creating Mobile Sample App Config" "-" "$logDir"
	cd ${MOBILE_WORKSPACE}/pm-apps/Sample1

	cat <<EOF > app.json
{
    "name": "Sample1",
    "version": "1.0",
    "starter": "sample-webapp",
    "dependencies": {
        "sample-webapp": "0.0.1"
    }
}

EOF

	__append_new_head_log "Defining mobile Sample App" "-" "$logDir"
	pm define

	__append_new_head_log "Loading Mobile Sample App Data" "-" "$logDir"
	cd ${MOBILE_WORKSPACE}/webapps/MobileExample-WebApp-Sample
	pm import --data ./test/data/data.json --app ../../pm-apps/Sample1/app.json

	pwd
    echo "*********************  done  createMobileReferenceApp *********************** "

}

function createAnalyticFrameworkServiceInstance() {
	__append_new_head_log "Create Analytic Framework Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $ANALYTIC_FRAMEWORK_SERVICE_INSTANCE_NAME
	fi

	if [[ "$TRUSTED_ISSUER_ID" == "" ]]; then
	  getTrustedIssuerIdFromInstance $UAA_INSTANCE_NAME
	fi

	if [[ $USE_TRAINING_UAA == 1 ]]; then
		configParameters="{\"trustedIssuerIds\":[\"$TRUSTED_ISSUER_ID\"]}"
		__try_create_service_using_cfcli $ANALYTIC_FRAMEWORK_SERVICE_NAME $ANALYTIC_FRAMEWORK_SERVICE_PLAN $ANALYTIC_FRAMEWORK_SERVICE_INSTANCE_NAME $configParameters "Analytic Framework Service"
	else
		configParameters="{\"trustedIssuerIds\":[\"$TRUSTED_ISSUER_ID\"]}"
		# Create instance of Predix Analytic Framework Service
		__try_create_af_service $ANALYTIC_FRAMEWORK_SERVICE_NAME $ANALYTIC_FRAMEWORK_SERVICE_PLAN $ANALYTIC_FRAMEWORK_SERVICE_INSTANCE_NAME $UAA_INSTANCE_NAME $ASSET_INSTANCE_NAME $TIMESERIES_INSTANCE_NAME $UAA_ADMIN_SECRET $UAA_CLIENTID_GENERIC $UAA_CLIENTID_GENERIC_SECRET $UAA_CLIENTID_LOGIN $UAA_CLIENTID_LOGIN_SECRET $ANALYTIC_UI_USER_NAME $ANALYTIC_UI_PASSWORD $ANALYTIC_UI_USER_EMAIL $INSTANCE_PREPENDER "Predix AF Service"
		#__try_create_service_using_cfcli $ANALYTIC_FRAMEWORK_SERVICE_NAME $ANALYTIC_FRAMEWORK_SERVICE_PLAN $ANALYTIC_FRAMEWORK_SERVICE_INSTANCE_NAME $configParameters "Analytic Framework Service"
	fi
}

function createRabbitMQInstance() {
	__append_new_head_log "Create RabbitMQ Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $RABBITMQ_SERVICE_INSTANCE_NAME
	fi

	# Create instance of RabbitMQ Service
	configParameters="{}" #no config params for rabbit mq creation
	__try_create_service_using_cfcli $RABBITMQ_SERVICE_NAME $RABBITMQ_SERVICE_PLAN $RABBITMQ_SERVICE_INSTANCE_NAME $configParameters "Predix RabbitMQ Service"

	# Bind Temp App to RabbitMQ Service Instance
	#__try_bind $1 $RABBITMQ_SERVICE_INSTANCE_NAME
}

function bindRabbitMQInstance() {
	__append_new_head_log "Bind RabbitMQ Service Instance" "-" "$logDir"

	# Bind Given App to RabbitMQ Service Instance
	__try_bind $1 $RABBITMQ_SERVICE_INSTANCE_NAME
}

function setEnv() {
	__append_new_head_log "Setting Env vars" "-" "$logDir"

	__try_setenv $1 $2 $3
}

function restageApp() {
	__append_new_head_log "Restage" "-" "$logDir"

	__try_restage $1
}

function createDeviceService() {
  __append_new_head_log "Create Client for Devices" "-" "$logDir"
	if [[ "$UAA_URL" == "" ]]; then
		getUaaUrlFromInstance $UAA_INSTANCE_NAME
	fi
	__createDeviceClient "$UAA_URL" "$UAA_CLIENTID_DEVICE" "$UAA_CLIENTID_DEVICE_SECRET"
	__addTimeseriesAuthorities $UAA_CLIENTID_DEVICE
}

# one arg: service name
function createRedisInstance() {
    __append_new_head_log "Create Redis Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $REDIS_INSTANCE_NAME
	fi

	# Create instance of RabbitMQ Service
	__try_create_service_using_cfcli $1 $REDIS_SERVICE_PLAN $REDIS_INSTANCE_NAME "{}" "Redis Service"
}

# one arg: service name
function createPredixCacheInstance() {
    __append_new_head_log "Create Predix Cache Service Instance" "-" "$logDir"

	if [[ $RUN_DELETE_SERVICES -eq 1 ]]; then
	   __try_delete_service $PREDIX_CACHE_INSTANCE_NAME
	fi

	# Create instance of RabbitMQ Service
	__try_create_service_using_cfcli $PREDIX_CACHE_SERVICE_NAME $PREDIX_CACHE_SERVICE_PLAN $PREDIX_CACHE_INSTANCE_NAME "{}" "Predix Cache Service"
}

#main sript starts here
function __setupServices() {
	__validate_num_arguments 1 $# "\"predix-services-setup.sh\" expected in order: Name of Predix Application used to get VCAP configurations" "$logDir"

	if [[ ( $BINDING_APP == 1 ) ]]; then
		pushAnAppForBinding $1
	fi

	if [[ $RUN_CREATE_UAA == 1 ]]; then
		createUaa $1
		# Create client ID for generic use by applications - including timeseries and asset scope
		__append_new_head_log "Registering Client on UAA to access the Predix Services" "-" "$logDir"
		if [[ "$UAA_URL" == "" ]]; then
			getUaaUrlFromInstance $UAA_INSTANCE_NAME
		fi

		__createUaaLoginClient "$UAA_URL" "$UAA_CLIENTID_LOGIN" "$UAA_CLIENTID_LOGIN_SECRET"
		if [[ $USE_TRAINING_UAA == 1 ]]; then
			__createUaaAppClient "$UAA_URL" "$UAA_CLIENTID_GENERIC" "$UAA_CLIENTID_GENERIC_SECRET"
		fi
		# Create a new user account
		if [[ $RUN_CREATE_MOBILE != 1 ]]; then
			# moble service creates user itself
			__addUaaUser "$UAA_URL"
		fi

	fi

	if [[ ( $RUN_CREATE_ASSET == 1 ) ]]; then
		createAssetService $1
		if [[ $USE_TRAINING_UAA == 1 ]]; then
			__addAssetAuthorities $UAA_CLIENTID_GENERIC
		fi
	fi

	if [[ ( $RUN_CREATE_MOBILE == 1 ) ]]; then
		createMobileService $1
	fi

	if [[ ( $RUN_CREATE_MOBILE_REF_APP == 1 ) ]]; then
		createMobileReferenceApp
	fi

	if [[ ( $RUN_CREATE_TIMESERIES == 1 ) ]]; then
		createTimeseries $1
		if [[ $USE_TRAINING_UAA == 1 ]]; then
			__addTimeseriesAuthorities $UAA_CLIENTID_GENERIC
		fi
	fi
	if [[ ( $RUN_CREATE_EVENT_HUB == 1 ) ]]; then
		createEventHubService $1
		if [[ $USE_TRAINING_UAA == 1 ]]; then
			__addEventHubAuthorities $UAA_CLIENTID_GENERIC
		fi
	fi
	if [[ ( $RUN_CREATE_BLOBSTORE == 1 ) ]]; then
		createBlobstoreService $1
	fi
	if [[ ( $RUN_CREATE_ACS == 1 ) ]]; then
		createACSService $1
		if [[ $USE_TRAINING_UAA == 1 ]]; then
			__addAcsAuthorities $UAA_CLIENTID_GENERIC
		fi
	fi

	if [[ ( $RUN_CREATE_ANALYTIC_FRAMEWORK == 1 ) ]]; then
		createAnalyticFrameworkServiceInstance $1
		__addAnalyticFrameworkAuthorities $UAA_CLIENTID_GENERIC
	fi

	if [[ ( $RUN_CREATE_PREDIX_CACHE == 1 ) ]]; then
		createPredixCacheInstance $1
	fi

	#get some variables for printing purposes below
	if [[ "$RUN_CREATE_TIMESERIES" == "1" ]]; then
		if [[ ( $BINDING_APP == 0 ) ]]; then
			if [[ "$TIMESERIES_INGEST_URI" == "" ]]; then
				getTimeseriesIngestUriFromInstance $TIMESERIES_INSTANCE_NAME
			fi
			if [[ "$TIMESERIES_QUERY_URI" == "" ]]; then
				getTimeseriesQueryUriFromInstance $TIMESERIES_INSTANCE_NAME
			fi
			if [[ "$TIMESERIES_ZONE_ID" == "" ]]; then
				getTimeseriesZoneIdFromInstance $TIMESERIES_INSTANCE_NAME
			fi
		else
			if [[ "$TIMESERIES_INGEST_URI" == "" ]]; then
				getTimeseriesIngestUriFromInstance $TIMESERIES_INSTANCE_NAME
			fi
			if [[ "$TIMESERIES_QUERY_URI" == "" ]]; then
				getTimeseriesQueryUriFromInstance $TIMESERIES_INSTANCE_NAME
			fi
			if [[ "$TIMESERIES_ZONE_ID" == "" ]]; then
				getTimeseriesZoneIdFromInstance $TIMESERIES_INSTANCE_NAME
			fi
		fi
	fi
	cd "$rootDir"

	__append_new_line_log "Predix Services Configurations found in file: \"$SUMMARY_TEXTFILE\"" "$logDir"

	echo ""  >> $SUMMARY_TEXTFILE
	echo "Predix Services Configuration"  >> $SUMMARY_TEXTFILE
	echo "--------------------------------------------------"  >> $SUMMARY_TEXTFILE
	echo ""  >> $SUMMARY_TEXTFILE
	echo "Installed UAA with a client_id/secret (for your app) and a user/password (for your users to log in to your app)" >> $SUMMARY_TEXTFILE

	if [[ ( $RUN_CREATE_TIMESERIES == 1 ) ]]; then
	    echo "Installed Time Series and added time series scopes as client_id authorities" >> $SUMMARY_TEXTFILE
	fi

	if [[ ( $RUN_CREATE_ASSET == 1 ) ]]; then
	    echo "Installed Asset and added asset scopes as client_id authorities" >> $SUMMARY_TEXTFILE
	fi

	echo "" >> $SUMMARY_TEXTFILE
	echo "UAA URL: $UAA_URL" >> $SUMMARY_TEXTFILE
	echo "UAA Admin Client ID: admin" >> $SUMMARY_TEXTFILE
	echo "UAA Admin Client Secret: $UAA_ADMIN_SECRET" >> $SUMMARY_TEXTFILE
	echo "UAA Generic Client ID: $UAA_CLIENTID_GENERIC" >> $SUMMARY_TEXTFILE
	echo "UAA Generic Client Secret: $UAA_CLIENTID_GENERIC_SECRET" >> $SUMMARY_TEXTFILE
	echo "UAA User ID: $UAA_USER_NAME" >> $SUMMARY_TEXTFILE
	echo "UAA User PASSWORD: $UAA_USER_PASSWORD" >> $SUMMARY_TEXTFILE

	if [[ ( $RUN_CREATE_MOBILE == 1 ) ]]; then
	    echo "Mobile Api Gateway Short Route Url: $API_GATEWAY_SHORT_ROUTE" >> $SUMMARY_TEXTFILE
	    echo "Mobile Zone ID: $MOBILE_ZONE_ID" >> $SUMMARY_TEXTFILE
    fi

	if [[ ( $RUN_CREATE_TIMESERIES == 1 ) ]]; then
        echo "TimeSeries Ingest URL:  $TIMESERIES_INGEST_URI" >> $SUMMARY_TEXTFILE
        echo "TimeSeries Query URL:  $TIMESERIES_QUERY_URI" >> $SUMMARY_TEXTFILE
        echo "TimeSeries ZoneID: $TIMESERIES_ZONE_ID" >> $SUMMARY_TEXTFILE
	fi

	if [[ ( $RUN_CREATE_ASSET == 1 ) ]]; then
        echo "Asset URL:  $ASSET_URI" >> $SUMMARY_TEXTFILE
        echo "Asset Zone ID: $ASSET_ZONE_ID" >> $SUMMARY_TEXTFILE
	fi


	if [[ ( $RUN_CREATE_BLOBSTORE == 1 ) ]]; then
		echo "" >> $SUMMARY_TEXTFILE
		echo "Blobstore SDK Application has been installed. You can submit and query blobstore using the SDK urls below"
		echo " to Post a file : curl -i -X POST -H \"Content-Type: multipart/form-data\" -F \"file=@<File name with absolute path>\" $apphost/v1/blob"
		echo " to Retrieve the files curl -i -X GET $apphost/v1/blob"
	fi
}
