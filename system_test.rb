#!/usr/bin/env ruby

# N.B. Il tempo è tiranno e non riesco a espandere meglio questa sezione di test, mi rendo però conto che è proprio "basilare"

require "systemu"

# Setto i componenti necessarei per il test
PRODUCER_SCRIPT = "producer.rb"
CONSUMER_SCRIPT = "consumer.rb"

# Funzione per eseguire uno script in background in un nuovo thread
def run_script(script)
  Thread.new { system(script) }
end

# Funzione per attivare/disattivare rabbitMQ
# Su mac os utilizzo rabbitmq tramite brew, va cambiato in base alla configurazione e all'os
def start_rabbitmq
  puts "Avvio di RabbitMQ..."
  status, stdout, stderr = systemu('brew services start rabbitmq')

  if status.success?
    puts "RabbitMQ avviato con successo."
  else
    puts "Si è verificato un errore durante l'avvio di RabbitMQ:"
    puts stderr
  end
end
def stop_rabbitmq
  puts "Arresto di RabbitMQ..."
  status, stdout, stderr = systemu('brew services stop rabbitmq')

  if status.success?
    puts "RabbitMQ fermato con successo."
  else
    puts "Si è verificato un errore durante l'arresto di RabbitMQ:"
    puts stderr
  end
end

# Avvio il broker RabbitMQ
start_rabbitmq

# Avvio il producer in background
producer_thread = run_script(PRODUCER_SCRIPT)

# Attendo che il producer invii i primi 10 messaggi di test
sleep(10)

# Fermo il producer
producer_thread.kill

# Avvia il consumer in background
consumer_thread = run_script(CONSUMER_SCRIPT)

# Attendo che il consumer gestisca i messaggi
sleep(10)

# Fermo il consumer
consumer_thread.kill

# Controllo se ci sono messaggi non inviati rimasti nella directory
unsent_messages = Dir.glob('unsent_messages/*.txt')

if unsent_messages.empty?
  puts "[OK] Nessun messaggio presente in unsent_messages del producer."
else
  puts "!KO! Ci sono messaggi non inviati in unsent_messages del producer:"
  unsent_messages.each { |file| puts File.read(file) }
end

puts "-"*3

# Controllo se ci sono messaggi non elaborati nella coda principale
main_queue_messages       = `rabbitmqctl list_queues name messages | grep energy_queue`
puts main_queue_messages
main_queue_messages_total = main_queue_messages.split("\n").map { |line| line.split("\t")[1].to_i }.sum

if main_queue_messages_total == 0
  puts "[OK] La coda principale è vuota."
else
  puts "!KO! La coda principale contiene #{main_queue_messages_total} messaggi non elaborati."
end

puts "-"*3

# Controllo se ci sono messaggi non elaborati nella coda principale
dlx_queue_messages       = `rabbitmqctl list_queues name messages | grep energy_queue.dead_letter`
puts dlx_queue_messages
dlx_queue_messages_total = dlx_queue_messages.split("\n").map { |line| line.split("\t")[1].to_i }.sum

if dlx_queue_messages_total == 0
  puts "[OK] La coda DLX è vuota."
else
  puts "!KO! La coda DLX contiene #{dlx_queue_messages_total} messaggi non elaborati."
end

# Fermarmo il broker RabbitMQ
# stop_rabbitmq

# Esco con il codice di uscira corretto alla simulazione
exit(unsent_messages.empty? && main_queue_messages_total.zero? && dlx_queue_messages_total.zero? ? 0 : 1)
