# AWS EC2: running instances, named and grouped by their Name and Role tags.
#   sadame hosts --inventory hosts-aws.rb
reply = JSON.parse(command_output("aws ec2 describe-instances " \
                                  "--filters Name=instance-state-name,Values=running --output json"))

reply["Reservations"].each do |reservation|
  reservation["Instances"].each do |instance|
    tags = {}
    (instance["Tags"] || []).each { |tag| tags[tag["Key"]] = tag["Value"] }
    next if instance["PublicIpAddress"].nil?

    role = (tags["Role"] || "unassigned").to_sym
    group role do
      host tags["Name"] || instance["InstanceId"], address: instance["PublicIpAddress"], user: "ec2-user"
    end
  end
end
