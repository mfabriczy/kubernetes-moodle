resource "aws_iam_user" "s3_spinnaker_moodle_artifacts" {
  name = "spinnaker-moodle-artifact"
}

resource "aws_s3_bucket" "s3_spinnaker_moodle_artifacts" {
  bucket = "ENTER-BUCKET-NAME-HERE"
  acl    = "private"
  tags = {
    Environment = "Production"
  }
}

resource "aws_iam_user_policy" "s3_spinnaker_moodle_artifacts" {
  name = ""
  user = "${aws_iam_user.s3_spinnaker_moodle_artifacts.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::ENTER-BUCKET-NAME-HERE/*"
      ]
    }
  ]
}
EOF
}