terraform plan
terraform apply
ssh fedora@THE-IP

If needed, update the subnet below
sudo tailscale up --advertise-routes=10.0.0.0/16 --accept-routes
login
on the console, find the machine, kebab, edit route settings - accept (can do it autmoatmically later)

from the subnet router:
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/16 -d 100.64.0.0/10 -j MASQUERADE
