#!/bin/bash

set -eu

AWS=/usr/local/bin/aws

REGION=us-west-2

# VPC Setting
VPC_CIDR=10.0.0.0/16
PUBLIC_SUBNET_1=10.0.1.0/24
PUBLIC_SUBNET_2=10.0.2.0/24
PRIVATE_SUBNET_1=10.0.3.0/24
PRIVATE_SUBNET_2=10.0.4.0/24

# RDS Setting
DBInstanceType=db.t2.micro
DBSize=20
DBName=sampledb
DBUser=dbuser
DBPassword=password

# EC2 Setting
InstanceType=t2.micro
KeyName=ssh_key_name
ImageId=ami-7172b611

# AutoScale Setting
MinSize=2
MaxSize=3


if [ $# != 2 ]; then
  echo "usage: $0 (project_name) (target)"
  echo "target:"
  echo "  all - Create ALL stack"
  echo "  vpc - Create only VPC stack"
  echo "  sg  - Create only SecurityGroup stack"
  echo "  iam - Create only IAM stack"
  echo "  efs - Create only EFS stack"
  echo "  elb - Create only ELB stack"
  echo "  rds - Create only RDS stack"
  echo "  as  - Create only AutoScale stack"
  exit 1
fi

PROJECT_NAME=$1
TARGET=$2

create_lambda_stack () {
  echo "#######################"
  echo "Create Lambda Stack..."
  echo "#######################"

  LAMBDA_ARN=`$AWS cloudformation describe-stacks \
    --region $REGION \
    --stack-name $PROJECT_NAME-lambda \
    | jq -r '.Stacks[].Outputs[].OutputValue'` >/dev/null 2>&1

  if [ ! $LAMBDA_ARN ]; then

    $AWS cloudformation create-stack \
      --region $REGION \
      --capabilities CAPABILITY_IAM \
      --stack-name $PROJECT_NAME-lambda \
      --template-body file://./lambda.cform

    $AWS cloudformation wait stack-create-complete \
      --region $REGION \
      --stack-name $PROJECT_NAME-lambda

    LAMBDA_ARN=`$AWS cloudformation describe-stacks \
    --region $REGION \
    --stack-name $PROJECT_NAME-lambda \
    | jq -r '.Stacks[].Outputs[].OutputValue'`
  fi


}

create_vpc_stack () {
  echo "#######################"
  echo "Create VPC Stack..."
  echo "#######################"

  $AWS cloudformation create-stack \
    --region $REGION \
    --stack-name $PROJECT_NAME-vpc \
    --parameters \
      ParameterKey=VpcCidrBlock,ParameterValue=$VPC_CIDR \
      ParameterKey=Public1SubnetCidrBlock,ParameterValue=$PUBLIC_SUBNET_1 \
      ParameterKey=Public2SubnetCidrBlock,ParameterValue=$PUBLIC_SUBNET_2 \
      ParameterKey=Private1SubnetCidrBlock,ParameterValue=$PRIVATE_SUBNET_1 \
      ParameterKey=Private2SubnetCidrBlock,ParameterValue=$PRIVATE_SUBNET_2 \
    --template-body file://./vpc.cform

  $AWS cloudformation wait stack-create-complete \
    --region $REGION \
    --stack-name $PROJECT_NAME-vpc
}

create_sg_stack () {
  echo "#######################"
  echo "Create SecurityGroup Stack..."
  echo "#######################"

  $AWS cloudformation create-stack \
    --region $REGION \
    --stack-name $PROJECT_NAME-sg \
    --parameters \
      ParameterKey=LookupLambdaFunction,ParameterValue=$LAMBDA_ARN \
      ParameterKey=VPCStackName,ParameterValue=$PROJECT_NAME-vpc \
    --template-body file://./sg.cform 

    $AWS cloudformation wait stack-create-complete \
    --region $REGION \
    --stack-name $PROJECT_NAME-sg
}

create_iam_stack () {
  echo "#######################"
  echo "Create IAM Stack..."
  echo "#######################"

  $AWS cloudformation create-stack \
    --region $REGION \
    --stack-name $PROJECT_NAME-iam \
    --capabilities CAPABILITY_IAM \
    --template-body file://./iam.cform

  $AWS cloudformation wait stack-create-complete \
    --region $REGION \
    --stack-name $PROJECT_NAME-iam
}

create_rds_stack () {

  echo "#######################"
  echo "Create RDS Stack..."
  echo "#######################"

  $AWS cloudformation create-stack \
    --region $REGION \
    --stack-name $PROJECT_NAME-rds \
    --parameters \
      ParameterKey=LookupLambdaFunction,ParameterValue=$LAMBDA_ARN \
      ParameterKey=VPCStackName,ParameterValue=$PROJECT_NAME-vpc \
      ParameterKey=SGStackName,ParameterValue=$PROJECT_NAME-sg \
      ParameterKey=DBInstanceType,ParameterValue=$DBInstanceType \
      ParameterKey=DBSize,ParameterValue=$DBSize \
      ParameterKey=DBName,ParameterValue=$DBName \
      ParameterKey=DBUser,ParameterValue=$DBUser \
      ParameterKey=DBPassword,ParameterValue=$DBPassword \
    --template-body file://./rds.cform 

  $AWS cloudformation wait stack-create-complete \
    --region $REGION \
    --stack-name $PROJECT_NAME-rds

}

create_efs_stack () {
  echo "#######################"
  echo "Create EFS Stack..."
  echo "#######################"

  $AWS cloudformation create-stack \
    --region $REGION \
    --stack-name $PROJECT_NAME-efs \
    --parameters \
      ParameterKey=LookupLambdaFunction,ParameterValue=$LAMBDA_ARN \
      ParameterKey=VPCStackName,ParameterValue=$PROJECT_NAME-vpc \
      ParameterKey=SGStackName,ParameterValue=$PROJECT_NAME-sg \
    --template-body file://./efs.cform 

    $AWS cloudformation wait stack-create-complete \
    --region $REGION \
    --stack-name $PROJECT_NAME-efs
}

create_elb_stack () {
  echo "#######################"
  echo "Create ELB Stack..."
  echo "#######################"

  $AWS cloudformation create-stack \
    --region $REGION \
    --stack-name $PROJECT_NAME-elb \
    --parameters \
      ParameterKey=LookupLambdaFunction,ParameterValue=$LAMBDA_ARN \
      ParameterKey=VPCStackName,ParameterValue=$PROJECT_NAME-vpc \
      ParameterKey=SGStackName,ParameterValue=$PROJECT_NAME-sg \
    --template-body file://./elb.cform 

    $AWS cloudformation wait stack-create-complete \
    --region $REGION \
    --stack-name $PROJECT_NAME-elb
}

create_as_stack () {
  echo "#######################"
  echo "Create AutoScale Stack..."
  echo "#######################"

  $AWS cloudformation create-stack \
    --region $REGION \
    --stack-name $PROJECT_NAME-as \
    --parameters \
      ParameterKey=LookupLambdaFunction,ParameterValue=$LAMBDA_ARN \
      ParameterKey=VPCStackName,ParameterValue=$PROJECT_NAME-vpc \
      ParameterKey=SGStackName,ParameterValue=$PROJECT_NAME-sg \
      ParameterKey=IAMStackName,ParameterValue=$PROJECT_NAME-iam \
      ParameterKey=EFSStackName,ParameterValue=$PROJECT_NAME-efs \
      ParameterKey=ELBStackName,ParameterValue=$PROJECT_NAME-elb \
      ParameterKey=InstanceType,ParameterValue=$InstanceType \
      ParameterKey=KeyName,ParameterValue=$KeyName \
      ParameterKey=ImageId,ParameterValue=$ImageId \
      ParameterKey=MinSize,ParameterValue=$MinSize \
      ParameterKey=MaxSize,ParameterValue=$MaxSize \
    --template-body file://./as.cform 

    $AWS cloudformation wait stack-create-complete \
    --region $REGION \
    --stack-name $PROJECT_NAME-as
}

create_lambda_stack

if [ $TARGET = "all" ] || [ $TARGET = "vpc" ]; then
  create_vpc_stack
fi

if [ $TARGET = "all" ] || [ $TARGET = "sg" ]; then
  create_sg_stack
fi

if [ $TARGET = "all" ] || [ $TARGET = "iam" ]; then
  create_iam_stack
fi

if [ $TARGET = "all" ] || [ $TARGET = "rds" ]; then
  create_rds_stack
fi

if [ $TARGET = "all" ] || [ $TARGET = "efs" ]; then
  create_efs_stack
fi

if [ $TARGET = "all" ] || [ $TARGET = "elb" ]; then
  create_elb_stack
fi

if [ $TARGET = "all" ] || [ $TARGET = "as" ]; then
  create_as_stack
fi
