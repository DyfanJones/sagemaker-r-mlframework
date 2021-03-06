# NOTE: This code has been modified from AWS Sagemaker Python:
# https://github.com/aws/sagemaker-python-sdk/blob/master/tests/unit/test_rl.py

library(sagemaker.core)
library(sagemaker.common)
library(sagemaker.mlcore)

DATA_DIR = file.path(getwd(), "data")
SCRIPT_PATH =file.path(DATA_DIR, "dummy_script.py")
TAR_FILE <- file.path(DATA_DIR, "test_tar.tgz")
BIN_OBJ <- readBin(con = TAR_FILE, what = "raw", n = file.size(TAR_FILE))
TIMESTAMP = "2017-11-06-14:14:15.672"
TIME = 1510006209.073025
BUCKET_NAME = "notmybucket"
INSTANCE_COUNT = 1
INSTANCE_TYPE = "ml.c4.4xlarge"
IMAGE_URI = "sagemaker-rl"
IMAGE_URI_FORMAT_STRING = "520713654638.dkr.ecr.%s.amazonaws.com/%s-%s:%s%s-%s-py3"
PYTHON_VERSION = "py3"
ROLE = "Dummy"
REGION = "us-west-2"
GPU = "ml.p2.xlarge"
CPU = "ml.c4.xlarge"
coach_tensorflow_version = "0.10"
coach_mxnet_version = "0.11.0"
ray_tensorflow_version = "0.8.5"

ENDPOINT_DESC = list("EndpointConfigName"="test-endpoint")

ENDPOINT_CONFIG_DESC = list("ProductionVariants"=list(list("ModelName"="model-1"), list("ModelName"="model-2")))

LIST_TAGS_RESULT = list("Tags"=list(list("Key"="TagtestKey", "Value"="TagtestValue")))

EXPERIMENT_CONFIG = list(
  "ExperimentName"="exp",
  "TrialName"="trial",
  "TrialComponentDisplayName"="tc")

sagemaker_session <- function(){
  paws_mock <- Mock$new(name = "PawsCredentials", region_name = REGION)
  sms <- Mock$new(
    name = "Session",
    paws_credentials = paws_mock,
    paws_region_name=REGION,
    config=NULL,
    local_mode=FALSE,
    s3 = NULL
  )

  s3_client <- Mock$new()
  s3_client$.call_args("put_object")
  s3_client$.call_args("get_object", list(Body = BIN_OBJ))

  sagemaker_client <- Mock$new()
  describe = list("ModelArtifacts"= list("S3ModelArtifacts"= "s3://m/m.tar.gz"))
  describe_compilation = list("ModelArtifacts"= list("S3ModelArtifacts"= "s3://m/model_c5.tar.gz"))

  sagemaker_client$.call_args("describe_training_job", describe)
  sagemaker_client$.call_args("describe_endpoint", ENDPOINT_DESC)
  sagemaker_client$.call_args("describe_endpoint_config", ENDPOINT_CONFIG_DESC)
  sagemaker_client$.call_args("list_tags", LIST_TAGS_RESULT)

  sms$.call_args("default_bucket", BUCKET_NAME)
  sms$.call_args("expand_role", ROLE)
  sms$.call_args("train", list(TrainingJobArn = "sagemaker-rl-dummy"))
  sms$.call_args("create_model", "sagemaker-rl")
  sms$.call_args("endpoint_from_production_variants", "sagemaker-rl-endpoint")
  sms$.call_args("logs_for_job")
  sms$.call_args("wait_for_job")
  sms$.call_args("wait_for_compilation_job", describe_compilation)
  sms$.call_args("compile_model")

  sms$s3 <- s3_client
  sms$sagemaker <- sagemaker_client

  return(sms)
}

.get_full_cpu_image_uri = function(toolkit, toolkit_version, framework){
  return(sprintf(IMAGE_URI_FORMAT_STRING,
    REGION, IMAGE_URI, framework, toolkit, toolkit_version, "cpu")
  )
}

.create_train_job = function(toolkit, toolkit_version, framework){
    job_name = sprintf("%s-%s-.*", IMAGE_URI, framework)
  return(list(
    "image_uri"=.get_full_cpu_image_uri(toolkit, toolkit_version, framework),
    "input_mode"="File",
    "input_config"=list(
      list(
        "DataSource"=list(
          "S3DataSource"=list(
            "S3DataType"="S3Prefix",
            "S3Uri"=NULL,
            "S3DataDistributionType"="FullyReplicated")
        ),
        "ChannelName"="training"
      )
    ),
    "role"=ROLE,
    "job_name"=job_name,
    "output_config"=list("S3OutputPath"=sprintf("s3://%s/",BUCKET_NAME)),
    "resource_config"=list(
      "InstanceCount"=1,
      "InstanceType"="ml.c4.4xlarge",
      "VolumeSizeInGB"=30),
    "hyperparameters"=list(
      "sagemaker_submit_directory"=sprintf(
        "s3://%s/%s/source/sourcedir.tar.gz", BUCKET_NAME, job_name),
      "sagemaker_program"="dummy_script.py",
      "sagemaker_container_log_level"="20",
      "sagemaker_job_name"=job_name,
      "sagemaker_region"='us-west-2',
      "sagemaker_s3_output"=sprintf('s3://%s/',BUCKET_NAME),
      "sagemaker_estimator"='RLEstimator'),
    "stop_condition"=list("MaxRuntimeInSeconds"=24 * 60 * 60),
    "vpc_config"=NULL,
    "metric_definitions"=list(
      list("Name"="reward-training", "Regex"="^Training>.*Total reward=(.*?),"),
      list("Name"="reward-testing", "Regex"="^Testing>.*Total reward=(.*?),")),
    "experiment_config"=NULL,
    "debugger_hook_config"=list(
      "S3OutputPath"=sprintf("s3://%s/",BUCKET_NAME),
      "CollectionConfigurations"=list()
    ),
    "profiler_rule_configs"=list(
      list(
        "RuleConfigurationName"="ProfilerReport-.*",
        "RuleEvaluatorImage"="895741380848.dkr.ecr.us-west-2.amazonaws.com/sagemaker-debugger-rules:latest",
        "RuleParameters"=list("rule_to_invoke"="ProfilerReport")
        )
      ),
    "profiler_config"=list(
      "S3OutputPath"=sprintf("s3://%s/",BUCKET_NAME)
      )
    )
  )
}

.rl_estimator = function(
  sagemaker_session,
  toolkit=RLToolkit$COACH,
  toolkit_version=RLEstimator$public_fields$COACH_LATEST_VERSION_MXNET,
  framework=RLFramework$MXNET,
  instance_type=NULL,
  base_job_name=NULL,
  ...){
  `%||%` <- sagemaker.mlframework:::`%||%`
  return(RLEstimator$new(
    entry_point=SCRIPT_PATH,
    toolkit=toolkit,
    toolkit_version=toolkit_version,
    framework=framework,
    role=ROLE,
    sagemaker_session=sagemaker_session,
    instance_count=INSTANCE_COUNT,
    instance_type=instance_type %||% INSTANCE_TYPE,
    base_job_name=base_job_name,
    ...)
  )
}

test_that("test create rl model", {
  container_log_level = 'INFO'
  source_dir = "s3://mybucket/source"
  sms <- sagemaker_session()

  rl = RLEstimator$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    toolkit=RLToolkit$COACH,
    toolkit_version=coach_tensorflow_version,
    framework=RLFramework$TENSORFLOW,
    container_log_level=container_log_level,
    source_dir=source_dir)

  rl$fit(inputs="s3://mybucket/train", job_name="new_name")

  model = rl$create_model()

  supported_versions = sagemaker.mlframework:::TOOLKIT_FRAMEWORK_VERSION_MAP[[RLToolkit$COACH]]
  framework_version = supported_versions[[coach_tensorflow_version]][[RLFramework$TENSORFLOW]]

  expect_true(inherits(model, "TensorFlowModel"))
  expect_identical(model$sagemaker_session, sms)
  expect_equal(model$framework_version, framework_version)
  expect_equal(model$role, ROLE)
  expect_equal(model$.container_log_level, 20)
  expect_null(model$vpc_config)
})

test_that("test create mxnet model", {
  container_log_level = 'INFO'
  source_dir = "s3://mybucket/source"
  sms <- sagemaker_session()

  rl = RLEstimator$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    toolkit=RLToolkit$COACH,
    toolkit_version=coach_mxnet_version,
    framework=RLFramework$MXNET,
    container_log_level=container_log_level,
    source_dir=source_dir)

  rl$fit(inputs="s3://mybucket/train", job_name="new_name")

  model = rl$create_model()

  model$.container_log_level

  supported_versions = sagemaker.mlframework:::TOOLKIT_FRAMEWORK_VERSION_MAP[[RLToolkit$COACH]]
  framework_version = supported_versions[[coach_mxnet_version]][[RLFramework$MXNET]]

  expect_true(inherits(model, "MXNetModel"))
  expect_identical(model$sagemaker_session, sms)
  expect_equal(model$framework_version, framework_version)
  expect_equal(model$role, ROLE)
  expect_equal(model$container_log_level, "20")
  expect_null(model$vpc_config)
})

test_that("test create model with optional params",{
  container_log_level = 'INFO'
  source_dir = "s3://mybucket/source"
  sms <- sagemaker_session()

  rl = RLEstimator$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    toolkit=RLToolkit$COACH,
    toolkit_version=coach_mxnet_version,
    framework=RLFramework$MXNET,
    container_log_level=container_log_level,
    source_dir=source_dir)

  rl$fit(job_name="new_name")

  new_role = "role"
  new_entry_point = "deploy_script.py"
  vpc_config = list("Subnets"=list("foo"), "SecurityGroupIds"=list("bar"))
  model_name = "model-name"
  model = rl$create_model(
    role=new_role, entry_point=new_entry_point, vpc_config_override=vpc_config, name=model_name
  )

  expect_equal(model$role, new_role)
  expect_equal(model$vpc_config, vpc_config)
  expect_equal(model$entry_point, new_entry_point)
  expect_equal(model$name, model_name)
})

test_that("test create model with custom image",{
  container_log_level = 'INFO'
  source_dir = "s3://mybucket/source"
  image = "selfdrivingcars:9000"
  sms <- sagemaker_session()

  rl = RLEstimator$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    image_uri=image,
    container_log_level=container_log_level,
    source_dir=source_dir)

  job_name = "new_name"
  rl$fit(job_name=job_name)

  new_entry_point = "deploy_script.py"
  model = rl$create_model(entry_point=new_entry_point)

  expect_equal(model$sagemaker_session, sms)
  expect_equal(model$image_uri, image)
  expect_equal(model$entry_point, new_entry_point)
  expect_equal(model$role, ROLE)
  expect_equal(model$container_log_level,"20")
  expect_equal(model$source_dir, source_dir)
})

test_that("test rl", {
  sms <- sagemaker_session()

  rl = RLEstimator$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    toolkit=RLToolkit$COACH,
    toolkit_version=coach_mxnet_version,
    framework=RLFramework$MXNET)

  inputs = "s3://mybucket/train"

  rl$fit(inputs=inputs, experiment_config=EXPERIMENT_CONFIG)

  expected_train_args = .create_train_job(
    RLToolkit$COACH, coach_mxnet_version, RLFramework$MXNET)
  expected_train_args[["input_config"]][[1]][["DataSource"]][["S3DataSource"]][["S3Uri"]] = inputs
  expected_train_args[["experiment_config"]] = EXPERIMENT_CONFIG

  actual_train_args = sms$train(..return_value = T)

  expect_identical(sort(names(actual_train_args)), sort(names(expected_train_args)))

  actual_hp = actual_train_args[["hyperparameters"]]
  expected_hp = expected_train_args[["hyperparameters"]]
  actual_train_args[["hyperparameters"]] = NULL
  expected_train_args[["hyperparameters"]] = NULL

  for (i in names(actual_hp)){
    if(i %in% c("sagemaker_job_name", "sagemaker_submit_directory"))
      expect_true(grepl(expected_hp[[i]], actual_hp[[i]]))
    else
      expect_equal(expected_hp[[i]], actual_hp[[i]])
  }

  expect_rule_conf = expected_train_args[["profiler_rule_configs"]][[1]][["RuleConfigurationName"]]
  actual_rule_conf = actual_train_args[["profiler_rule_configs"]][[1]][["RuleConfigurationName"]]
  expected_train_args[["profiler_rule_configs"]][[1]][["RuleConfigurationName"]]= NULL
  actual_train_args[["profiler_rule_configs"]][[1]][["RuleConfigurationName"]] = NULL

  for (i in names(expected_train_args)){
    if(i == "job_name")
      expect_true(grepl(expected_train_args[[i]], actual_train_args[[i]]))
    else
      expect_equal(expected_train_args[[i]], actual_train_args[[i]])
  }
})

test_that("test deploy mxnet", {
  sms <- sagemaker_session()

  rl = .rl_estimator(
    sms,
    RLToolkit$COACH,
    coach_mxnet_version,
    RLFramework$MXNET,
    instance_type="ml.g2.2xlarge")
  rl$fit()
  predictor = rl$deploy(1, CPU)
  expect_true(inherits(predictor, "MXNetPredictor"))
})

test_that("test deploy tfs", {
  sms <- sagemaker_session()

  rl <- .rl_estimator(
    sms,
    RLToolkit$COACH,
    coach_tensorflow_version,
    RLFramework$TENSORFLOW,
    instance_type="ml.g2.2xlarge")
  rl$fit()
  expect_warning({predictor = rl$deploy(1, GPU)})
  expect_true(inherits(predictor, "TensorFlowPredictor"))
})

test_that("test deploy ray", {
  sms <- sagemaker_session()

  rl = .rl_estimator(
    sms,
    RLToolkit$RAY,
    ray_tensorflow_version,
    RLFramework$TENSORFLOW,
    instance_type="ml.g2.2xlarge")
  rl$fit()

  error_msg = paste(
    "Automatic deployment of Ray models is not currently available.",
    "Train policy parameters are available in model checkpoints in the TrainingJob output.")
  expect_error(
    rl$deploy(1, GPU),
    error_msg,
    class = "NotImplementedError"
  )
})

test_that("test training image uri", {
  toolkit = RLToolkit$RAY
  framework = RLFramework$TENSORFLOW
  sms <- sagemaker_session()

  image = "custom-image:latest"

  rl = .rl_estimator(
    sms,
    toolkit,
    ray_tensorflow_version,
    framework,
    instance_type=CPU,
    image_uri=image)

  expect_equal(image, rl$training_image_uri())
})

test_that("test attach",{
  training_image = sprintf("1.dkr.ecr.us-west-2.amazonaws.com/sagemaker-rl-%s:%s%s-cpu-py3",
    RLFramework$MXNET, RLToolkit$COACH, coach_mxnet_version)
  supported_versions = sagemaker.mlframework:::TOOLKIT_FRAMEWORK_VERSION_MAP[[RLToolkit$COACH]]
  framework_version = supported_versions[[coach_mxnet_version]][[RLFramework$MXNET]]
  returned_job_description = list(
    "AlgorithmSpecification"=list("TrainingInputMode"="File", "TrainingImage"=training_image),
    "HyperParameters"=list(
      "sagemaker_submit_directory"="s3://some/sourcedir.tar.gz",
      "sagemaker_program"="train_coach.py",
      "sagemaker_container_log_level"="INFO",
      "sagemaker_job_name"="neo",
      "training_steps"="100",
      "sagemaker_region"="us-west-2"),
    "RoleArn"="arn:aws:iam::366:role/SageMakerRole",
    "ResourceConfig"=list(
      "VolumeSizeInGB"=30,
      "InstanceCount"=1,
      "InstanceType"="ml.c4.xlarge"),
    "StoppingCondition"=list("MaxRuntimeInSeconds"=24 * 60 * 60),
    "TrainingJobName"="neo",
    "TrainingJobStatus"="Completed",
    "TrainingJobArn"="arn:aws:sagemaker:us-west-2:336:training-job/neo",
    "OutputDataConfig"=list("KmsKeyId"="", "S3OutputPath"="s3://place/output/neo"),
    "TrainingJobOutput"=list("S3TrainingJobOutput"="s3://here/output.tar.gz")
  )

  sms <- sagemaker_session()
  sms$sagemaker$.call_args("describe_training_job", returned_job_description)

  rl = .rl_estimator(
    sms,
    RLToolkit$COACH,
    coach_mxnet_version,
    RLFramework$MXNET,
    instance_type="ml.g2.2xlarge")

  estimator = rl$attach(training_job_name="neo", sagemaker_session=sms)

  expect_equal(estimator$latest_training_job, "neo")
  expect_equal(estimator$framework, RLFramework$MXNET)
  expect_equal(estimator$toolkit, RLToolkit$COACH)
  expect_equal(estimator$framework_version,framework_version)
  expect_equal(estimator$toolkit_version, coach_mxnet_version)
  expect_equal(estimator$role, "arn:aws:iam::366:role/SageMakerRole")
  expect_equal(estimator$instance_count, 1)
  expect_equal(estimator$max_run, 24 * 60 * 60)
  expect_equal(estimator$input_mode,"File")
  expect_equal(estimator$base_job_name, "neo")
  expect_equal(estimator$output_path, "s3://place/output/neo")
  expect_equal(estimator$output_kms_key, "")
  expect_equal(estimator$hyperparameters()[["training_steps"]], "100")
  expect_equal(estimator$source_dir, "s3://some/sourcedir.tar.gz")
  expect_equal(estimator$entry_point, "train_coach.py")
  expect_equal(estimator$metric_definitions, RLEstimator$public_methods$default_metric_definitions(RLToolkit$COACH))
})

test_that("test attach wrong framework", {
  training_image = "1.dkr.ecr.us-west-2.amazonaws.com/sagemaker-mxnet-py2-cpu:1.0.4"
  rjd = list(
    "AlgorithmSpecification"=list("TrainingInputMode"="File", "TrainingImage"=training_image),
    "HyperParameters"=list(
      "sagemaker_submit_directory"="s3://some/sourcedir.tar.gz",
      "checkpoint_path"="s3://other/1508872349",
      "sagemaker_program"="iris-dnn-classifier.py",
      "sagemaker_container_log_level"="INFO",
      "training_steps"="100",
      "sagemaker_region"="us-west-2"),
    "RoleArn"="arn:aws:iam::366:role/SageMakerRole",
    "ResourceConfig"=list(
      "VolumeSizeInGB"=30,
      "InstanceCount"=1,
      "InstanceType"="ml.c4.xlarge"),
    "StoppingCondition"=list("MaxRuntimeInSeconds"=24 * 60 * 60),
    "TrainingJobName"="neo",
    "TrainingJobStatus"="Completed",
    "TrainingJobArn"="arn:aws:sagemaker:us-west-2:336:training-job/neo",
    "OutputDataConfig"=list("KmsKeyId"="", "S3OutputPath"="s3://place/output/neo"),
    "TrainingJobOutput"=list("S3TrainingJobOutput"="s3://here/output.tar.gz")
  )

  sms <- sagemaker_session()
  sms$sagemaker$.call_args("describe_training_job", rjd)

  rl = .rl_estimator(
    sms,
    RLToolkit$COACH,
    coach_mxnet_version,
    RLFramework$MXNET,
    instance_type="ml.g2.2xlarge")

  expect_error(
    rl$attach(training_job_name="neo", sagemaker_session=sms),
    "Training job: neo didn't use image for requested framework",
    class="ValueError"
  )
})

test_that("test attach custom image",{
  training_image = "rl:latest"
  returned_job_description = list(
    "AlgorithmSpecification"=list("TrainingInputMode"="File", "TrainingImage"=training_image),
    "HyperParameters"=list(
      "sagemaker_submit_directory"="s3://some/sourcedir.tar.gz",
      "sagemaker_program"="iris-dnn-classifier.py",
      "sagemaker_s3_uri_training"="sagemaker-3/integ-test-data/tf_iris",
      "sagemaker_container_log_level"="INFO",
      "sagemaker_job_name"="neo",
      "training_steps"="100",
      "sagemaker_region"="us-west-2"),
    "RoleArn"="arn:aws:iam::366:role/SageMakerRole",
    "ResourceConfig"=list(
      "VolumeSizeInGB"=30,
      "InstanceCount"=1,
      "InstanceType"="ml.c4.xlarge"),
    "StoppingCondition"=list("MaxRuntimeInSeconds"=24 * 60 * 60),
    "TrainingJobName"="neo",
    "TrainingJobStatus"="Completed",
    "TrainingJobArn"="arn:aws:sagemaker:us-west-2:336:training-job/neo",
    "OutputDataConfig"=list("KmsKeyId"="", "S3OutputPath"="s3://place/output/neo"),
    "TrainingJobOutput"=list("S3TrainingJobOutput"="s3://here/output.tar.gz")
  )

  sms <- sagemaker_session()
  sms$sagemaker$.call_args("describe_training_job", returned_job_description)

  rl = .rl_estimator(
    sms,
    RLToolkit$COACH,
    coach_mxnet_version,
    RLFramework$MXNET,
    instance_type="ml.g2.2xlarge")

  estimator = rl$attach(training_job_name="neo", sagemaker_session=sms)

  expect_equal(estimator$latest_training_job, "neo")
  expect_equal(estimator$image_uri, training_image)
  expect_equal(estimator$training_image_uri(), training_image)
})

test_that("test wrong framework format",{
  sms <- sagemaker_session()
  error_msg = "Invalid type.*"
  expect_error(
    RLEstimator$new(
      toolkit=RLToolkit$RAY,
      framework="TF",
      toolkit_version=RLEstimator$RAY_LATEST_VERSION,
      entry_point=SCRIPT_PATH,
      role=ROLE,
      sagemaker_session=sms,
      instance_count=INSTANCE_COUNT,
      instance_type=INSTANCE_TYPE,
      framework_version=NULL),
    error_msg,
    class="ValueError"
  )
})

test_that("test wrong toolkit format",{
  error_msg = "Invalid type.*"
  sms <- sagemaker_session()
  expect_error(
    RLEstimator$new(
      toolkit="coach2",
      framework=RLFramework$TENSORFLOW,
      toolkit_version=RLEstimator$public_fields$COACH_LATEST_VERSION_TF,
      entry_point=SCRIPT_PATH,
      role=ROLE,
      sagemaker_session=sms,
      instance_count=INSTANCE_COUNT,
      instance_type=INSTANCE_TYPE,
      framework_version=NULL),
    error_msg,
    class = "ValueError"
  )
})

test_that("test missing required parameters",{
  sms <- sagemaker_session()
  error_msg = "Please provide.*"
  expect_error(
    RLEstimator$new(
      entry_point=SCRIPT_PATH,
      role=ROLE,
      sagemaker_session=sms,
      instance_count=INSTANCE_COUNT,
      instance_type=INSTANCE_TYPE),
    error_msg,
    class = "AttributeError"
  )
})

test_that("test wrong type parameters",{
  sms <- sagemaker_session()
  error_msg = "Provided.*"
  expect_error(
    RLEstimator$new(
      toolkit=RLToolkit$COACH,
      framework=RLFramework$TENSORFLOW,
      toolkit_version=RLEstimator$public_fields$RAY_LATEST_VERSION,
      entry_point=SCRIPT_PATH,
      role=ROLE,
      sagemaker_session=sms,
      instance_count=INSTANCE_COUNT,
      instance_type=INSTANCE_TYPE),
    error_msg,
    class = "AttributeError"
  )
})
