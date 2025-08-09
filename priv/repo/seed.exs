require Logger

Logger.info("--- Running the seed script ---")


Logger.info("--- Starting data import ---")
NorthwindElixirTraders.DataImporter.import_all_modeled()

Logger.info("Data import ended. Result: #{inspect(NorthwindElixirTraders.DataImporter.check_all_imported_ok())}")
