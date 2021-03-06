# NOTE: This code has been modified from AWS Sagemaker Python:
# https://github.com/aws/sagemaker-python-sdk/tree/master/tests/unit/sagemaker/tensorflow

context("tensorflow")

library(sagemaker.core)
library(sagemaker.common)
library(sagemaker.mlcore)

DATA_DIR = file.path(getwd(), "data")
SCRIPT_FILE = "dummy_script.py"
SCRIPT_PATH =file.path(DATA_DIR, SCRIPT_FILE)
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
ACCELERATOR_TYPE = "ml.eia1.medium"
IMAGE_URI = "tensorflow-inference:2.0.0-cpu"

PREDICT_INPUT = list("instances"= c(1.0, 2.0, 5.0))
PREDICT_RESPONSE = list("predictions"= list(c(3.5, 4.0, 5.5), c(3.5, 4.0, 5.5)))
CLASSIFY_INPUT = list(
  "signature_name"= "tensorflow/serving/classify",
  "examples"= list(list("x"= 1.0), list("x"= 2.0))
)
CLASSIFY_RESPONSE = list("result"= list(c(0.4, 0.6), c(0.2, 0.8)))
REGRESS_INPUT = list(
  "signature_name"= "tensorflow/serving/regress",
  "examples"= list(list("x"= 1.0), list("x"= 2.0))
)


JOB_NAME = "sagemaker-tensorflow-scriptmode-.*"
IMAGE_URI_FORMAT_STRING = "520713654638.dkr.ecr.%s.amazonaws.com/sagemaker-tensorflow-scriptmode:%s-cpu-%s"

DISTRIBUTION_PS_ENABLED = list("parameter_server"=list("enabled"=TRUE))
DISTRIBUTION_MPI_ENABLED = list(
  "mpi"=list("enabled"=TRUE, "custom_mpi_options"="options", "processes_per_host"=2)
)
DISTRIBUTION_SM_DDP_ENABLED = list("smdistributed"=list("dataparallel"=list("enabled"=TRUE)))

ROLE = "Dummy"
REGION = "us-west-2"
GPU = "ml.p2.xlarge"
CPU = "ml.c4.xlarge"
tensorflow_inference_version = "2.1.1"
tensorflow_inference_py_version = "py3"

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
  sms$.call_args("train", list(TrainingJobArn = "sagemaker-tf-dummy"))
  sms$.call_args("create_model", "sagemaker-tf")
  sms$.call_args("endpoint_from_production_variants", "sagemaker-tf-endpoint")
  sms$.call_args("logs_for_job")
  sms$.call_args("wait_for_job")
  sms$.call_args("wait_for_compilation_job", describe_compilation)
  sms$.call_args("compile_model")

  sms$s3 <- s3_client
  sms$sagemaker <- sagemaker_client

  return(sms)
}

.build_tf <- function(sagemaker_session, ...){
  return(TensorFlow$new(
    sagemaker_session=sagemaker_session,
    entry_point="dummy.py",
    role="dummy-role",
    instance_count=1,
    instance_type="ml.c4.xlarge",
    ...
    )
  )
}

.image_uri <- function(tf_version, py_version){
  return(sprintf(IMAGE_URI_FORMAT_STRING, REGION, tf_version, py_version))
}

.hyperparameters <- function(horovod=FALSE, smdataparallel=FALSE){
  hps = list(
    "sagemaker_submit_directory"= sprintf(
      "s3://%s/%s/source/sourcedir.tar.gz", BUCKET_NAME, JOB_NAME),
    "sagemaker_program"= "dummy_script.py",
    "sagemaker_container_log_level"= 20,
    "sagemaker_job_name"= JOB_NAME,
    "sagemaker_region"= "us-west-2"
  )
  if (horovod || smdataparallel)
    hps$model_dir = "/opt/ml/model"
  else
    hps$model_dir = sprintf("s3://%s/%s/model", BUCKET_NAME, JOB_NAME)
  return(hps)
}

.create_train_job <- function(tf_version, horovod=FALSE, ps=FALSE, py_version="py2", smdataparallel=FALSE){
  conf = list(
    "input_config"= list(
      list(
        "DataSource"= list(
          "S3DataSource"= list(
            "S3DataType"= "S3Prefix",
            "S3Uri" = NULL,
            "S3DataDistributionType"= "FullyReplicated"
            )
        ),
        "ChannelName"= "training"
      )
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
    "hyperparameters"= .hyperparameters(horovod, smdataparallel),
    "image_uri"= .image_uri(tf_version, py_version)
  )

  if (!ps)
    conf$debugger_hook_config = list(
      "S3OutputPath"= sprintf("s3://%s/", BUCKET_NAME),
      "CollectionConfigurations"= list()
    )

  profiler_rule_configs = list(
    list(
      "RuleConfigurationName"= "ProfilerReport-.*",
      "RuleEvaluatorImage"= "895741380848.dkr.ecr.us-west-2.amazonaws.com/sagemaker-debugger-rules:latest",
      "RuleParameters"= list("rule_to_invoke"= "ProfilerReport")
      )
    )
  profiler_config = list("S3OutputPath"= sprintf("s3://%s/",BUCKET_NAME))

  conf[["profiler_rule_configs"]] = profiler_rule_configs
  conf[["profiler_config"]] = profiler_config
  return(conf)
}
# ===== test estimator init ====

test_that("test estimator py2 deprecation warning", {
  sms <- sagemaker_session()
  estimator = .build_tf(sms,framework_version="2.1.1", py_version="py2")
  expect_equal(estimator$py_version, "py2")
})

test_that("test py2 version deprecated", {
  sms <- sagemaker_session()
  expect_error(
    .build_tf(sms, framework_version="2.1.2", py_version="py2"))
})

test_that("test py2 version is not deprecated", {
  estimator = .build_tf(sagemaker_session(), framework_version="1.15.0", py_version="py2")
  expect_equal(estimator$py_version, "py2")
  estimator = .build_tf(sagemaker_session(), framework_version="2.0.0", py_version="py2")
  expect_equal(estimator$py_version, "py2")
})

test_that("test framework name", {
  tf = .build_tf(sagemaker_session(), framework_version="1.15.2", py_version="py3")
  expect_equal(attr(tf, "_framework_name"), "tensorflow")
})

test_that("test enable sm metrics", {
  tf = .build_tf(
    sagemaker_session(),
    framework_version="1.15.2",
    py_version="py3",
    enable_sagemaker_metrics=TRUE
  )
  expect_true(tf$enable_sagemaker_metrics)
})

test_that("test disable sm metrics", {
  tf = .build_tf(
    sagemaker_session(),
    framework_version="1.15.2",
    py_version="py3",
    enable_sagemaker_metrics=FALSE
  )
  expect_false(tf$enable_sagemaker_metrics)
})

test_that("test disable sm metrics if fw ver is less than 1.15", {
  tf = .build_tf(
    sagemaker_session(),
    framework_version="1.14",
    py_version="py3",
    image_uri="old-image",
  )
  expect_null(tf$enable_sagemaker_metrics)
})

test_that("test require image uri if fw ver is less than 1.11", {
  expect_error(
    .build_tf(
      sagemaker_session(),
      framework_version="1.10",
      py_version="py2"
    )
  )
})

# ===== test estimator attach ====

test_that("test attach", {
  training_image = ImageUris$new()$retrieve(
    "tensorflow",
    region=REGION,
    version="1.15",
    py_version="py3",
    instance_type="ml.c4.xlarge",
    image_scope="training")

  rjd = list(
    "AlgorithmSpecification"= list("TrainingInputMode"= "File", "TrainingImage"= training_image),
    "HyperParameters"= list(
      "sagemaker_submit_directory"= 's3://some/sourcedir.tar.gz',
      "sagemaker_program"= 'iris-dnn-classifier.py',
      "sagemaker_container_log_level"= 'INFO',
      "sagemaker_job_name"= 'neo'),
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

  tf = TensorFlow$new(sagemaker_session = sm,
                      framework_version="1.15",
                      py_version="py3",
                      entry_point="dummy.py",
                      role="dummy-role",
                      instance_count=1,
                      instance_type="ml.c4.xlarge")

  estimator = tf$attach(training_job_name="neo", sagemaker_session=sm)

  expect_equal(estimator$latest_training_job, "neo")
  expect_equal(estimator$py_version, "py3")
  expect_equal(estimator$framework_version, "1.15")
  expect_equal(estimator$role, "arn:aws:iam::366:role/SageMakerRole")
  expect_equal(estimator$instance_count, 1)
  expect_equal(estimator$max_run, 24*60*60)
  expect_equal(estimator$input_mode, "File")
  expect_equal(estimator$base_job_name, "neo")
  expect_equal(estimator$output_path, "s3://place/output/neo")
  expect_equal(estimator$output_kms_key, "")
  expect_true(!is.null(estimator$hyperparameters()))
  expect_equal(estimator$source_dir, 's3://some/sourcedir.tar.gz')
  expect_equal(estimator$entry_point, 'iris-dnn-classifier.py')
  expect_equal(estimator$training_image_uri(), training_image)
})

test_that("test attach old container", {
  training_image = "1.dkr.ecr.us-west-2.amazonaws.com/sagemaker-tensorflow-py2-cpu:1.0"

  rjd = list(
    "AlgorithmSpecification"= list("TrainingInputMode"= "File", "TrainingImage"= training_image),
    "HyperParameters"= list(
      "sagemaker_submit_directory"= 's3://some/sourcedir.tar.gz',
      "sagemaker_program"= 'iris-dnn-classifier.py',
      "sagemaker_container_log_level"= 'INFO',
      "sagemaker_job_name"= 'neo'),
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

  tf = TensorFlow$new(sagemaker_session = sm,
                      framework_version="1.15",
                      py_version="py3",
                      entry_point="dummy.py",
                      role="dummy-role",
                      instance_count=1,
                      instance_type="ml.c4.xlarge")

  estimator = tf$attach(training_job_name="neo", sagemaker_session=sm)

  expect_equal(estimator$latest_training_job, "neo")
  expect_equal(estimator$py_version, "py2")
  expect_equal(estimator$framework_version, "1.4")
  expect_equal(estimator$role, "arn:aws:iam::366:role/SageMakerRole")
  expect_equal(estimator$instance_count, 1)
  expect_equal(estimator$max_run, 24*60*60)
  expect_equal(estimator$input_mode, "File")
  expect_equal(estimator$base_job_name, "neo")
  expect_equal(estimator$output_path, "s3://place/output/neo")
  expect_equal(estimator$output_kms_key, "")
  expect_equal(estimator$source_dir, 's3://some/sourcedir.tar.gz')
  expect_equal(estimator$entry_point, 'iris-dnn-classifier.py')
})

test_that("test attach wrong framework", {
  returned_job_description = list(
    "AlgorithmSpecification"= list(
      "TrainingInputMode"= "File",
      "TrainingImage"= "1.dkr.ecr.us-west-2.amazonaws.com/sagemaker-mxnet-py2-cpu:1.0"),
    "HyperParameters"= list(
      "sagemaker_submit_directory"= 's3://some/sourcedir.tar.gz',
      "sagemaker_program"= 'iris-dnn-classifier.py',
      "sagemaker_container_log_level"= 'logging.INFO'),
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

  tf = TensorFlow$new(sagemaker_session = sm,
                      framework_version="1.15",
                      py_version="py3",
                      entry_point="dummy.py",
                      role="dummy-role",
                      instance_count=1,
                      instance_type="ml.c4.xlarge")

  expect_error(tf$attach(training_job_name="neo", sagemaker_session=sm),
               "neo didn't use image for requested framework")
})

test_that("test attach custom image", {
  training_image = "1.dkr.ecr.us-west-2.amazonaws.com/tensorflow_with_custom_binary:1.0"
  rjd = list(
    "AlgorithmSpecification"= list("TrainingInputMode"= "File", "TrainingImage"= training_image),
    "HyperParameters"= list(
      "sagemaker_submit_directory"= 's3://some/sourcedir.tar.gz',
      "sagemaker_program"= 'iris-dnn-classifier.py',
      "sagemaker_container_log_level"= 'INFO',
      "sagemaker_job_name"= 'neo'),
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

  tf = TensorFlow$new(sagemaker_session = sm,
                      framework_version="1.15",
                      py_version="py3",
                      entry_point="dummy.py",
                      role="dummy-role",
                      instance_count=1,
                      instance_type="ml.c4.xlarge")

  estimator = tf$attach(training_job_name="neo", sagemaker_session=sm)
  expect_equal(estimator$image_uri, training_image)
  expect_equal(estimator$training_image_uri(), training_image)
})

# ===== test estimator ====

############### check this part
test_that("test create model", {
  container_log_level = 'INFO'
  base_job_name = "job"
  sms <- sagemaker_session()

  tf = TensorFlow$new(
    entry_point=SCRIPT_PATH,
    source_dir="s3://mybucket/source",
    framework_version=tensorflow_inference_version,
    py_version=tensorflow_inference_py_version,
    role=ROLE,
    sagemaker_session=sms,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    container_log_level=container_log_level,
    base_job_name=base_job_name,
    enable_network_isolation=TRUE,
    output_path="s3://mybucket/output")

  tf$.current_job_name = "doing something"
  model = tf$create_model()

  expect_equal(model$sagemaker_session, sms)
  expect_equal(model$framework_version, tensorflow_inference_version)
  expect_null(model$entry_point)
  expect_equal(model$role, ROLE)
  expect_equal(model$.container_log_level, 20)
  expect_null(model$source_dir)
  expect_null(model$vpc_config)
  expect_true(model$enable_network_isolation())
})

test_that("test create model_with optional params", {
  container_log_level = 'INFO'
  source_dir = "job"
  sms <- sagemaker_session()

  tf = TensorFlow$new(
    entry_point=SCRIPT_PATH,
    framework_version=tensorflow_inference_version,
    py_version=tensorflow_inference_py_version,
    role=ROLE,
    sagemaker_session=sms,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    container_log_level=container_log_level,
    base_job_name="job",
    source_dir=source_dir,
    output_path="s3://mybucket/output")

  tf$.current_job_name = "doing something"

  new_role = "role"
  vpc_config = list("Subnets"= list("foo"), "SecurityGroupIds"= list("bar"))
  model_name = "model-name"
  model = tf$create_model(
    role=new_role,
    vpc_config_override=vpc_config,
    entry_point=SERVING_SCRIPT_FILE,
    name=model_name,
    enable_network_isolation=TRUE)

  expect_equal(model$role, new_role)
  expect_equal(model$vpc_config, vpc_config)
  expect_equal(model$entry_point, SERVING_SCRIPT_FILE)
  expect_equal(model$name, model_name)
  expect_true(model$enable_network_isolation())
})

test_that("test create model with custom image", {
  container_log_level = 'INFO'
  source_dir = "s3://mybucket/source"
  custom_image = "tensorflow:1.0"
  sms <- sagemaker_session()

  tf = TensorFlow$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    image_uri=custom_image,
    container_log_level=container_log_level,
    base_job_name="job",
    source_dir=source_dir)

  job_name = "doing something"
  tf$fit(inputs="s3://mybucket/train", job_name=job_name)
  model = tf$create_model()

  expect_equal(model$image_uri, custom_image)
})

test_that("test fit", {
  sms <- sagemaker_session()
  tf = TensorFlow$new(
    entry_point=SCRIPT_FILE,
    framework_version="1.11",
    py_version="py2",
    role=ROLE,
    sagemaker_session=sms,
    instance_type=INSTANCE_TYPE,
    instance_count=1,
    source_dir=DATA_DIR)

  inputs = "s3://mybucket/train"
  tf$fit(inputs=inputs)

  expected_train_args = .create_train_job("1.11", py_version = "py2")
  expected_train_args$input_config[[1]]$DataSource$S3DataSource$S3Uri = inputs

  actual_train_args = sms$train(..return_value = T)
  actual_train_args$job_name = NULL

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

  # check if list of parameters is created correctly
  expect_equal(expected_train_args,actual_train_args)
})

test_that("test fit ps", {
  sms <- sagemaker_session()
  tf = TensorFlow$new(
    entry_point=SCRIPT_FILE,
    framework_version="1.11",
    py_version="py2",
    role=ROLE,
    sagemaker_session=sms,
    instance_type=INSTANCE_TYPE,
    instance_count=1,
    source_dir=DATA_DIR,
    distribution=DISTRIBUTION_PS_ENABLED)

  inputs = "s3://mybucket/train"
  tf$fit(inputs=inputs)

  expected_train_args = .create_train_job("1.11", ps=TRUE, py_version="py2")
  expected_train_args$input_config[[1]]$DataSource$S3DataSource$S3Uri = inputs
  expected_train_args[["hyperparameters"]][[Framework$public_fields$LAUNCH_PS_ENV_NAME]] = TRUE

  actual_train_args = sms$train(..return_value = T)
  actual_train_args$job_name = NULL

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

  # check if list of parameters is created correctly
  expect_equal(expected_train_args,actual_train_args)
})

test_that("test fit mpi", {
  sms <- sagemaker_session()
  tf = TensorFlow$new(
    entry_point=SCRIPT_FILE,
    framework_version="1.11",
    py_version="py2",
    role=ROLE,
    sagemaker_session=sms,
    instance_type=INSTANCE_TYPE,
    instance_count=1,
    source_dir=DATA_DIR,
    distribution=DISTRIBUTION_MPI_ENABLED)

  inputs = "s3://mybucket/train"
  tf$fit(inputs=inputs)

  expected_train_args = .create_train_job("1.11", horovod=TRUE, py_version="py2")
  expected_train_args$input_config[[1]]$DataSource$S3DataSource$S3Uri = inputs
  expected_train_args[["hyperparameters"]][[Framework$public_fields$LAUNCH_MPI_ENV_NAME]] = TRUE
  expected_train_args[["hyperparameters"]][[Framework$public_fields$MPI_NUM_PROCESSES_PER_HOST]] = "2"
  expected_train_args[["hyperparameters"]][[Framework$public_fields$MPI_CUSTOM_MPI_OPTIONS]] = "options"

  actual_train_args = sms$train(..return_value = T)
  actual_train_args$job_name = NULL

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

  # check if list of parameters is created correctly
  expect_equal(expected_train_args,actual_train_args)
})

test_that("test hyperparameters no model dir",{
  sms <- sagemaker_session()
  tf = TensorFlow$new(
    entry_point=SCRIPT_PATH,
    framework_version="1.15.2",
    py_version="py3",
    role=ROLE,
    sagemaker_session=sms,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    base_job_name=NULL,
    image_uri="tensorflow:latest",
    model_dir=FALSE)

  hyperparameters = tf$hyperparameters()

  expect_false("model_dir" %in% names(hyperparameters))
})

test_that("test hyperparameters no model dir",{
  custom_image = "tensorflow:latest"
  sms <- sagemaker_session()
  tf = TensorFlow$new(
    entry_point=SCRIPT_PATH,
    role=ROLE,
    sagemaker_session=sms,
    instance_count=INSTANCE_COUNT,
    instance_type=INSTANCE_TYPE,
    image_uri=custom_image)

  expect_equal(custom_image, tf$training_image_uri())
})

