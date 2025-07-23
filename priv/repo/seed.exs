require Logger

Logger.info("--- Running the seed script ---")


Logger.info("--- Starting data import ---")
result = NorthwindElixirTraders.DataImporter.import_all_modeled()

Logger.info("Data import complete. Result: #{inspect(result)}")
Logger.info("--- Successfully completed! ---")
