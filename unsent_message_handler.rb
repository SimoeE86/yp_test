#!/usr/bin/env ruby

require "securerandom"

# Questo modulo, a utilizzo del producer,  salva i messaggi su disco e li cancella solo dopo che siano stati realmente inviati
# questo torna utile in caso venga riavviato il producer con dei messaggi in attesa di essere inviati al brooker che per qualche motivo
# non è disponibile in quel frangente di tempo
module UnsentMessageHandler
  # Nome della dir
  MESSAGE_FOLDER = "unsent_messages"

  def self.init
    # Crea la cartella se non esiste
    Dir.mkdir(MESSAGE_FOLDER) unless File.directory?(MESSAGE_FOLDER)
  end

  def self.save_message(message)
    # Salvo il messaggio per comodità e ordinamento utilizzo la data di invio
    # Valutare se nel mondo reale è permesso salvare dati "possibilmente sensibili" su disco,
    # ad ogni modo la consegna specificava un invio manuale via shell quindi chi scrive conosce già il contenuto
    # il SecureRandom.hex(2) serve per abilitare il salvataggio di più di un messaggio al secondo (per il test)
    # Potrebbe essere utile gestire gli errori di salvataggio su disco
    file_path = File.join(MESSAGE_FOLDER, "#{[Time.now.to_i, SecureRandom.hex(2)].join("_")}.txt")
    File.open(file_path, 'w') do |file|
      file.puts(message)
    end
    file_path
  end

  # Per comodità carico tutti i messaggi in un array, in modo di poterli reinviare agevolmente
  def self.load_unsent_messages
    unsent_messages = []
    Dir.glob(File.join(MESSAGE_FOLDER, '*.txt')).each do |file_path|
      unsent_messages << { message: File.read(file_path), file_path: file_path }
    end
    unsent_messages
  end

  # Cancello il messaggio da disco
  def self.delete_unsent_message(file_path)
    File.delete(file_path)
  end

end
