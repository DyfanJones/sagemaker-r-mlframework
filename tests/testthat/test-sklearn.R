# NOTE: This code has been modified from AWS Sagemaker Python:
# https://github.com/aws/sagemaker-python-sdk/blob/master/tests/unit/test_sklearn.py
context("SKLearn")

library(sagemaker.core)
library(sagemaker.common)
library(sagemaker.mlcore)

DATA_DIR = file.path(getwd(), "data")
SCRIPT_PATH =file.path(DATA_DIR, "dummy_script.py")
TAR_FILE <- file.path(DATA_DIR, "test_tar.tgz")
BIN_OBJ <- readBin(con = TAR_FILE, what = "raw", n = file.size(TAR_FILE))
SERVING_SCRIPT_FILE = "another_dummy_script.py"
MODEL_DATA = "s3://some/data.tar.gz"
ENV = list("DUMMY_ENV_VAR"= "dummy_value")
TIMESTAMP = "2017-11-06-14:14:15.672"
TIME = 1507167947
BUCKET_NAME = "mybucket"
INSTANCE_COUNT = 1
INSTANCE_TYPE = "ml.c4.4xlarge"
GPU_INSTANCE_TYPE = "ml.p2.xlarge"
IMAGE_URI = "sagemaker-scikit-learn"
JOB_NAME = sprintf("%s", IMAGE_URI)
IMAGE_URI_FORMAT_STRING = "246618743249.dkr.ecr.%s.amazonaws.com/%s:%s-%s-%s"
ROLE = "Dummy"
REGION = "us-west-2"
GPU = "ml.p2.xlarge"
CPU = "ml.c4.xlarge"
sklearn_version = "0.23-1"
PYTHON_VERSION = "py3"

ENDPOINT_DESC = list("EndpointConfigName"="test-endpoint")

ENDPOINT_CONFIG_DESC = list("ProductionVariants"= list(list("ModelName"= "model-1"), list("ModelName"= "model-2")))

LIST_TAGS_RESULT = list("Tags"= list(list("Key"= "TagtestKey", "Value"= "TagtestValue")))

EXPERIMENT_CONFIG = list(
  "ExperimentName"= "exp",
  "TrialName"= "trial",
  "TrialComponentDisplayName"= "tc"
)

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
  sms$.call_args("train", list(TrainingJobArn = "sagemaker-sklearn-dummy"))
  sms$.call_args("create_model", "sagemaker-sklearn")
  sms$.call_args("endpoint_from_production_variants", "sagemaker-sklearn-endpoint")
  sms$.call_args("logs_for_job")
  sms$.call_args("wait_for_job")
  sms$.call_args("wait_for_compilation_job", describe_compilation)
  sms$.call_args("compile_model")

  sms$s3 <- s3_client
  sms$sagemaker <- sagemaker_client

  return(sms)
}

.get_full_cpu_image_uri <- function(version){
  return(sprintf(IMAGE_URI_FORMAT_STRING,REGION, IMAGE_URI, version, "cpu", PYTHON_VERSION))
}

.create_train_job <- function(version, py_version){
  return(list(
    "input_config"= list(
      list(
        "DataSource"= list(
          "S3DataSource"= list(
            "S3DataType"= "S3Prefix",
            "S3Uri" = NULL,
            "S3DataDistributionType"= "FullyReplicated")
          ),
        "ChannelName"= "training")
      ),
    "role"= ROLE,
    "output_config"= list("S3OutputPath"= sprintf("s3://%s/",BUCKET_NAME)),
    "resource_config"= list(
      "InstanceCount"= 1,
      "InstanceType"= "ml.c4.4xlarge",
      "VolumeSizeInGB"= 30),
    "stop_condition"= list("MaxRuntimeInSeconds"= 24 * 60 * 60),
    "vpc_config"= NULL,
    "input_mode"= "File",
    "job_name"= sprintf("^%s[0-9-]+", JOB_NAME),
    "hyperparameters"= list(
      "sagemaker_submit_directory"= sprintf(
        "s3://%s/%s[0-9-]+/source/sourcedir.tar.gz", BUCKET_NAME, JOB_NAME),
      "sagemaker_program"= "dummy_script.py",
      "sagemaker_container_log_level"= 20,
      "sagemaker_job_name"= sprintf("^%s[0-9-]+", JOB_NAME),
      "sagemaker_region"= 'us-west-2'),
    "experiment_config"= NULL,
    "image_uri"= .get_full_cpu_image_uri(version),
    "debugger_hook_config"= list(
      "S3OutputPath"= sprintf("s3://%s/",BUCKET_NAME),
      "CollectionConfigurations"= list()),
    "profiler_rule_configs"=list(list(
        "RuleConfigurationName"="ProfilerReport-[0-9]+",
        "RuleEvaluatorImage"="895741380848.dkr.ecr.us-west-2.amazonaws.com/sagemaker-debugger-rules:latest",
        "RuleParameters"=list("rule_to_invoke"="ProfilerReport"))
        ),
    "profiler_config"=list(
      "S3OutputPath"=sprintf("s3://%s/",BUCKET_NAME))
    )
  )
}

test_that("test training image uri", {
  container_log_level = 'INFO'
  source_dir = "s3://mybucket/source"
  sms <- sagemaker_session()

  sklearn = SKLearn$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_type=INSTANCE_TYPE,
    framework_version=sklearn_version,
    container_log_level=container_log_level,
    py_version=PYTHON_VERSION,
    base_job_name="job",
    source_dir=source_dir
  )

  expect_equal(sklearn$training_image_uri(), .get_full_cpu_image_uri(sklearn_version))
})

test_that("test create model", {
  source_dir = "s3://mybucket/source"
  sms <- sagemaker_session()

  sklearn_model = SKLearnModel$new(
    model_data=source_dir,
    role=ROLE,
    sagemaker_session=sms,
    entry_point=SCRIPT_PATH,
    framework_version=sklearn_version
  )

  image_uri = .get_full_cpu_image_uri(sklearn_version)

  model_values = sklearn_model$prepare_container_def(CPU)
  expect_equal(model_values$Image, image_uri)
})

test_that("test create model with network isolation", {
  source_dir = "s3://mybucket/source"
  repacked_model_data = "s3://mybucket/prefix/model.tar.gz"
  sms <- sagemaker_session()

  sklearn_model = SKLearnModel$new(
    model_data=source_dir,
    role=ROLE,
    sagemaker_session=sms,
    entry_point=SCRIPT_PATH,
    enable_network_isolation=TRUE,
    framework_version=sklearn_version
  )

  sklearn_model$uploaded_code = list(s3_prefix=repacked_model_data, script_name="script")
  model_values = sklearn_model$prepare_container_def(CPU)

  expect_equal(model_values$Environment$SAGEMAKER_SUBMIT_DIRECTORY, "/opt/ml/model/code")
})

test_that("test create model from estimator", {
  container_log_level = 'INFO'
  source_dir = "s3://mybucket/source"
  base_job_name = "job"
  sms <- sagemaker_session()

  sklearn = SKLearn$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_type=INSTANCE_TYPE,
    framework_version=sklearn_version,
    container_log_level=container_log_level,
    py_version=PYTHON_VERSION,
    base_job_name=base_job_name,
    source_dir=source_dir,
    enable_network_isolation=TRUE
  )

  sklearn$fit(inputs="s3://mybucket/train", job_name="new_name")

  model = sklearn$create_model()

  expect_equal(model$sagemaker_session, sms)
  expect_equal(model$framework_version, sklearn_version)
  expect_equal(model$py_version, sklearn$py_version)
  expect_equal(model$entry_point, basename(SCRIPT_PATH))
  expect_equal(model$role, ROLE)
  expect_equal(model$container_log_level, "20")
  expect_equal(model$source_dir, source_dir)
  expect_null(model$vpc_config)
  expect_true(model$enable_network_isolation())
})

test_that("test create model with optional params", {
  container_log_level = 'INFO'
  source_dir = "s3://mybucket/source"
  sms <- sagemaker_session()

  sklearn = SKLearn$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_type=INSTANCE_TYPE,
    container_log_level=container_log_level,
    framework_version=sklearn_version,
    py_version=PYTHON_VERSION,
    base_job_name="job",
    source_dir=source_dir
  )

  sklearn$fit(inputs="s3://mybucket/train", job_name="new_name")

  custom_image = "ubuntu:latest"
  new_role = "role"
  model_server_workers = 2
  vpc_config = list("Subnets"= list("foo"), "SecurityGroupIds"= list("bar"))
  new_source_dir = "s3://myotherbucket/source"
  dependencies = list("/directory/a", "/directory/b")
  model_name = "model-name"
  model = sklearn$create_model(
    image_uri=custom_image,
    role=new_role,
    model_server_workers=model_server_workers,
    vpc_config_override=vpc_config,
    entry_point=SERVING_SCRIPT_FILE,
    source_dir=new_source_dir,
    dependencies=dependencies,
    name=model_name
  )

  expect_equal(model$image_uri, custom_image)
  expect_equal(model$role, new_role)
  expect_equal(model$model_server_workers, model_server_workers)
  expect_equal(model$vpc_config, vpc_config)
  expect_equal(model$entry_point, SERVING_SCRIPT_FILE)
  expect_equal(model$source_dir, new_source_dir)
  expect_equal(model$dependencies, dependencies)
  expect_equal(model$name, model_name)
})

test_that("test create model with custom image", {
  container_log_level = 'INFO'
  source_dir = "s3://mybucket/source"
  custom_image = "ubuntu:latest"
  sms <- sagemaker_session()

  sklearn = SKLearn$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_type=INSTANCE_TYPE,
    image_uri=custom_image,
    container_log_level=container_log_level,
    py_version=PYTHON_VERSION,
    base_job_name="job",
    source_dir=source_dir
  )

  sklearn$fit(inputs="s3://mybucket/train", job_name="new_name")
  model = sklearn$create_model()

  expect_equal(model$image_uri, custom_image)
})

test_that("test sklearn", {
  skip_if_no_python()
  skip_if_no_numpy()

  sms <- sagemaker_session()
  sklearn = SKLearn$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_type=INSTANCE_TYPE,
    py_version=PYTHON_VERSION,
    framework_version=sklearn_version
  )

  inputs = "s3://mybucket/train"

  sklearn$fit(inputs=inputs, experiment_config=EXPERIMENT_CONFIG)

  expected_train_args = .create_train_job(sklearn_version)
  expected_train_args$input_config[[1]]$DataSource$S3DataSource$S3Uri = inputs
  expected_train_args$experiment_config = EXPERIMENT_CONFIG

  actual_train_args = sms$train(..return_value = T)

  # check if keys are identical
  expect_equal(names(actual_train_args), names(expected_train_args))

  # check if hyperparameters are created correctly
  expected_hyperparameters = expected_train_args$hyperparameters
  actual_hyperparameters = actual_train_args$hyperparameters
  expected_train_args$hyperparameters = NULL
  actual_train_args$hyperparameters = NULL
  for (i in names(expected_hyperparameters)){
    expect_true(grepl(expected_hyperparameters[[i]], actual_hyperparameters[[i]]))
  }

  # check if rule configuration name is created correctly
  expected_RuleConfigurationName = expected_train_args$profiler_rule_configs[[1]]$RuleConfigurationName
  actual_RuleConfigurationName= actual_train_args$profiler_rule_configs[[1]]$RuleConfigurationName
  expected_train_args$profiler_rule_configs[[1]]$RuleConfigurationName = NULL
  actual_train_args$profiler_rule_configs[[1]]$RuleConfigurationName = NULL
  expect_true(grepl(expected_RuleConfigurationName, actual_RuleConfigurationName))

  expect_true(grepl(expected_train_args$job_name, actual_train_args$job_name))

  expected_train_args$job_name=NULL
  actual_train_args$job_name=NULL
  # check if list of parameters is created correctly
  expect_equal(expected_train_args,actual_train_args)

  model = sklearn$create_model()

  expected_image_base = "246618743249.dkr.ecr.us-west-2.amazonaws.com/sagemaker-scikit-learn:%s-cpu-%s"
  ll = model$prepare_container_def(CPU)
  expected_ll = list(
    "Image"= sprintf(expected_image_base,sklearn_version, PYTHON_VERSION),
    "Environment"= list(
      "SAGEMAKER_PROGRAM"= "dummy_script.py",
      "SAGEMAKER_SUBMIT_DIRECTORY"= "s3://mybucket/sagemaker-scikit-learn[0-9-]+/source/sourcedir.tar.gz",
      "SAGEMAKER_CONTAINER_LOG_LEVEL"= "20",
      "SAGEMAKER_REGION"= "us-west-2"),
    "ModelDataUrl"= "s3://m/m.tar.gz")

  expect_equal(ll[-2], expected_ll[-2])
  for (i in seq_along(ll$Environment)){
    if(names(ll$Environment[i]) == "SAGEMAKER_SUBMIT_DIRECTORY")
      expect_true(grepl(expected_ll$Environment[[i]], ll$Environment[[i]]))
    else expect_equal(ll$Environment[i], expected_ll$Environment[i])
  }

  predictor = sklearn$deploy(1, CPU)
  expect_true(inherits(predictor, "SKLearnPredictor"))
})

test_that("test transform multiple values for entry point issue", {
  sms <- sagemaker_session()

  sklearn = SKLearn$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_type=INSTANCE_TYPE,
    py_version=PYTHON_VERSION,
    framework_version=sklearn_version)

  inputs = "s3://mybucket/train"

  sklearn$fit(inputs=inputs)

  transformer = sklearn$transformer(instance_count=1, instance_type="ml.m4.xlarge")
  # if we got here, we didn't get a "multiple values" error
  expect_false(is.null(transformer))
  expect_true(inherits(transformer, "Transformer"))
})

test_that("test fail distributed training", {
  sms <- sagemaker_session()
  expect_error(
    SKLearn$new(
      entry_point=SCRIPT_PATH,
      role=ROLE,
      sagemaker_session=sms,
      instance_count=2,
      instance_type=INSTANCE_TYPE,
      py_version=PYTHON_VERSION,
      framework_version=sklearn_version)
    )
})

test_that("test fail gpu training", {
  sms <- sagemaker_session()
  expect_error(
    SKLearn$new(
      entry_point=SCRIPT_PATH,
      role=ROLE,
      sagemaker_session=sms,
      instance_type=GPU_INSTANCE_TYPE,
      py_version=PYTHON_VERSION,
      framework_version=sklearn_version)
  )
})

test_that("test model", {
  skip_if_no_python()
  skip_if_no_numpy()

  sms <- sagemaker_session()
  model = SKLearnModel$new(
    "s3://some/data.tar.gz",
    role=ROLE,
    entry_point=SCRIPT_PATH,
    framework_version=sklearn_version,
    sagemaker_session=sms)

  predictor = model$deploy(1, CPU)

  expect_true(inherits(predictor, "SKLearnPredictor"))
})

test_that("test attach", {
  training_image = sprintf("1.dkr.ecr.us-west-2.amazonaws.com/sagemaker-scikit-learn:%s-cpu-%s",
                           sklearn_version, PYTHON_VERSION)
  returned_job_description = list(
    "AlgorithmSpecification"= list("TrainingInputMode"= "File", "TrainingImage"= training_image),
    "HyperParameters"= list(
      "sagemaker_submit_directory"= 's3://some/sourcedir.tar.gz',
      "sagemaker_program"= 'iris-dnn-classifier.py',
      "sagemaker_s3_uri_training"= 'sagemaker-3/integ-test-data/tf_iris',
      "sagemaker_container_log_level"= 'INFO',
      "sagemaker_job_name"= 'neo',
      "training_steps"= "100",
      "sagemaker_region"= 'us-west-2'),
    "RoleArn"= "arn:aws:iam::366:role/SageMakerRole",
    "ResourceConfig"= list(
      "VolumeSizeInGB"= 30,
      "InstanceCount"= 1,
      "InstanceType"= "ml.c4.xlarge"),
    "StoppingCondition"= list("MaxRuntimeInSeconds"= 24 * 60 * 60),
    "TrainingJobName"= "neo",
    "TrainingJobStatus"= "Completed",
    "TrainingJobArn"= "arn:aws:sagemaker:us-west-2:336:training-job/neo",
    "OutputDataConfig"= list("KmsKeyId"= "", "S3OutputPath"= "s3://place/output/neo"),
    "TrainingJobOutput"= list("S3TrainingJobOutput"= "s3://here/output.tar.gz")
  )

  sms <- sagemaker_session()
  sms$sagemaker$.call_args("describe_training_job", returned_job_description)

  sklearn = SKLearn$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    framework_version=sklearn_version,
    py_version=PYTHON_VERSION)

  estimator = sklearn$attach(training_job_name="describe_training_job", sagemaker_session=sms)

  expect_equal(estimator$.current_job_name, "neo")
  expect_equal(estimator$latest_training_job, "neo")
  expect_equal(estimator$py_version, PYTHON_VERSION)
  expect_equal(estimator$framework_version, sklearn_version)
  expect_equal(estimator$role, "arn:aws:iam::366:role/SageMakerRole")
  expect_equal(estimator$instance_count, 1)
  expect_equal(estimator$max_run, 24 * 60 * 60)
  expect_equal(estimator$input_mode, "File")
  expect_equal(estimator$base_job_name, "neo")
  expect_equal(estimator$output_path, "s3://place/output/neo")
  expect_equal(estimator$output_kms_key, "")
  expect_equal(estimator$hyperparameters()$training_steps, "100")
  expect_equal(estimator$source_dir, "s3://some/sourcedir.tar.gz")
  expect_equal(estimator$entry_point, "iris-dnn-classifier.py")
})

test_that("test attach wrong framework", {
  rjd = list(
    "AlgorithmSpecification"= list(
      "TrainingInputMode"= "File",
      "TrainingImage"= "1.dkr.ecr.us-west-2.amazonaws.com/sagemaker-mxnet-py3-cpu:1.0.4"),
    "HyperParameters"= list(
      "sagemaker_submit_directory"= 's3://some/sourcedir.tar.gz',
      "checkpoint_path"= 's3://other/1508872349',
      "sagemaker_program"= 'iris-dnn-classifier.py',
      "sagemaker_container_log_level"= 'INFO',
      "training_steps"= "100",
      "sagemaker_region"= 'us-west-2'),
    "RoleArn"= "arn:aws:iam::366:role/SageMakerRole",
    "ResourceConfig"= list(
      "VolumeSizeInGB"= 30,
      "InstanceCount"= 1,
      "InstanceType"= "ml.c4.xlarge"),
    "StoppingCondition"= list("MaxRuntimeInSeconds"= 24 * 60 * 60),
    "TrainingJobName"= "neo",
    "TrainingJobStatus"= "Completed",
    "TrainingJobArn"= "arn:aws:sagemaker:us-west-2:336:training-job/neo",
    "OutputDataConfig"= list("KmsKeyId"= "", "S3OutputPath"= "s3://place/output/neo"),
    "TrainingJobOutput"= list("S3TrainingJobOutput"= "s3://here/output.tar.gz")
    )

  sm <- sagemaker_session()
  sm$sagemaker$.call_args("describe_training_job", rjd)

  sklearn = SKLearn$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sm,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    framework_version=sklearn_version,
    py_version=PYTHON_VERSION)

  expect_error(sklearn$attach(training_job_name="neo", sagemaker_session=sm))
})

test_that("test attach custom image", {
  training_image = "1.dkr.ecr.us-west-2.amazonaws.com/my_custom_sklearn_image:latest"
  returned_job_description = list(
    "AlgorithmSpecification"= list("TrainingInputMode"= "File", "TrainingImage"= training_image),
    "HyperParameters"= list(
      "sagemaker_submit_directory"= 's3://some/sourcedir.tar.gz',
      "sagemaker_program"= 'iris-dnn-classifier.py',
      "sagemaker_s3_uri_training"= 'sagemaker-3/integ-test-data/tf_iris',
      "sagemaker_container_log_level"= 'INFO',
      "sagemaker_job_name"= 'neo',
      "training_steps"= "100",
      "sagemaker_region"= 'us-west-2'),
    "RoleArn"= "arn:aws:iam::366:role/SageMakerRole",
    "ResourceConfig"= list(
      "VolumeSizeInGB"= 30,
      "InstanceCount"= 1,
      "InstanceType"= "ml.c4.xlarge"),
    "StoppingCondition"= list("MaxRuntimeInSeconds"= 24 * 60 * 60),
    "TrainingJobName"= "neo",
    "TrainingJobStatus"= "Completed",
    "TrainingJobArn"= "arn:aws:sagemaker:us-west-2:336:training-job/neo",
    "OutputDataConfig"= list("KmsKeyId"= "", "S3OutputPath"= "s3://place/output/neo"),
    "TrainingJobOutput"= list("S3TrainingJobOutput"= "s3://here/output.tar.gz")
  )

  sm <- sagemaker_session()
  sm$sagemaker$.call_args("describe_training_job", returned_job_description)

  sklearn = SKLearn$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sm,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    framework_version=sklearn_version,
    py_version=PYTHON_VERSION)

  estimator = sklearn$attach(training_job_name="neo", sagemaker_session=sm)
  expect_equal(estimator$latest_training_job, "neo")
  expect_equal(estimator$image_uri, training_image)
  expect_equal(estimator$training_image_uri(), training_image)
})

test_that("test estimator py2 warning", {
  expect_error(
    SKLearn$new(
      entry_point=SCRIPT_PATH,
      role=ROLE,
      sagemaker_session=sagemaker_session(),
      instance_count=INSTANCE_COUNT,
      instance_type=INSTANCE_TYPE,
      framework_version=sklearn_version,
      py_version="py2")
  )
})

test_that("test model py2 warning", {
  expect_error(
    SKLearnModel$new(
      model_data=source_dir,
      role=ROLE,
      entry_point=SCRIPT_PATH,
      sagemaker_session=sagemaker_session(),
      framework_version=sklearn_version,
      py_version="py2")
  )
})
