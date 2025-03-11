To get specific user information to run the terraform code, the amazon CLI is used which can be found at https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html if not already downloaded.


If you are using MacOS, run this code in your terminal to download Amazon CLI:

  $ curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"

  $ sudo installer -pkg AWSCLIV2.pkg -target /

  $ which aws

  $ aws --version

Once the code has been pulled and is ready to run, before running 'terraform plan' or 'terraform apply', run 'aws configure' in your terminal to enter your credentials.
