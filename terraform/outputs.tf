output "public_ip" {
  description = "Adresse IP publique de l'instance provisionnée"
  value       = aws_instance.lab.public_ip
}
