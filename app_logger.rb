#!/usr/bin/env ruby

# Importo la libreria logger
require 'logger'

# Creato la cartella di log se non presente
Dir.mkdir("log") unless File.directory?("log")

module AppLogger
  # Inizializza il logger e lo rende accessibile come una costante singleton
  LOGGER = Logger.new('log/app.log')

  # Metodo per rendere fruibile il logger all'esterno del modulo
  def self.logger
    LOGGER
  end
end
