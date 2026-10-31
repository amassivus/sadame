# DigitalOcean: every Droplet, in one group per tag.
#   sadame hosts --inventory hosts-doctl.rb
droplets = JSON.parse(command_output("doctl compute droplet list --output json"))

droplets.each do |droplet|
  public_ip = droplet["networks"]["v4"].find { |network| network["type"] == "public" }
  next if public_ip.nil?

  droplet["tags"].each do |tag|
    group tag.to_sym do
      host droplet["name"], address: public_ip["ip_address"], user: "root"
    end
  end
end
