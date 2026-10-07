ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # En paralelo con procesos (cada worker tiene su propia base SQLite). Con
    # threads comparten la conexión y se rompen las transacciones de los
    # fixtures; y Windows no tiene fork, así que ahí se corre en serie.
    parallelize(workers: Gem.win_platform? ? 1 : :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
