# LDlinkR::SNPclip

#' Prune a list of variants by linkage disequilibrium.
#'
#' @param snps a list of between 1 - 5,000 variants, using an rsID or chromosome coordinate (e.g. "chr7:24966446")
#' @param pop a 1000 Genomes Project population, (e.g. YRI or CEU), multiple allowed, default = "CEU"
#' @param r2_threshold LD R2 threshold between 0-1, default = 0.1
#' @param maf_threshold minor allele frequency threshold between 0-1, default = 0.01
#' @param token LDlink provided user token, default = NULL, register for token at \url{https://ldlink.nci.nih.gov/?tab=apiaccess}
#' @param file Optional character string naming a path and file for saving results.  If file = FALSE, no file will be generated, default = FALSE.
#' @param genome_build Choose between one of the three options...`grch37` for genome build GRCh37 (hg19),
#' `grch38` for GRCh38 (hg38), or `grch38_high_coverage` for GRCh38 High Coverage (hg38) 1000 Genome Project
#' data sets.  Default is GRCh37 (hg19).
#'
#' @return a data frame
#' @importFrom httr POST content stop_for_status http_error
#' @importFrom utils capture.output read.delim write.table
#' @export
#'
#' @examples
#' \dontrun{SNPclip(c("rs3", "rs4", "rs148890987"), "YRI", "0.1", "0.01",
#'                     token = Sys.getenv("LDLINK_TOKEN"))
#'                  }
#'
SNPclip <- function(snps,
                    pop="CEU",
                    r2_threshold="0.1",
                    maf_threshold="0.01",
                    token=NULL,
                    file = FALSE,
                    genome_build = "grch37") {

LD_config <- list(snpclip_url="https://ldlink.nci.nih.gov/LDlinkRest/snpclip",
                  avail_pop=c("YRI","LWK","GWD","MSL","ESN","ASW","ACB",
                              "MXL","PUR","CLM","PEL","CHB","JPT","CHS",
                              "CDX","KHV","CEU","TSI","FIN","GBR","IBS",
                              "GIH","PJL","BEB","STU","ITU",
                              "ALL", "AFR", "AMR", "EAS", "EUR", "SAS"),
                  avail_genome_build = c("grch37", "grch38", "grch38_high_coverage")
                             )


url <- LD_config[["snpclip_url"]]
avail_pop <- LD_config[["avail_pop"]]
avail_genome_build <- LD_config[["avail_genome_build"]]

# ensure file option is a character string
  file <- as.character(file)

# Define regular expressions used to check arguments for valid input below
  rsid_pattern <- "^rs\\d{1,}"
  # Syntax               Description
  # ^rs                  rsid starts with 'rs'
  # \\d{1,}              followed by 1 or more digits

  chr_coord_pattern <- "(^chr)(\\d{1,2}|X|x|Y|y):(\\d{1,9})$"
  # Syntax               Description
  # (^chr)               chromosome coordinate starts with 'chr'
  # (\\d{1,2}|X|x|Y|y)   followed by one or two digits, 'X', 'x', 'Y', 'y', to designate chromosome
  # :                    followed by a colon
  # (\\d{1,9})$          followed by 1 to 9 digits only to the end of string


# Checking arguments for valid input
  if(!(length(snps) > 1) & (length(snps) <= 5000)) {
    stop("Input is between 1 to 5000 variants.")
  }

  for(i in 1:length(snps)) {
    if(!((grepl(rsid_pattern, snps[i], ignore.case = TRUE)) | (grepl(chr_coord_pattern, snps[i], ignore.case = TRUE))))  {
      stop(paste("Invalid query format for variant: ",snps[i], ".", sep=""))
    }
  }

  if(!(all(pop %in% avail_pop))) {
    stop("Not a valid population code.")
  }

  # first, ensure 'r2_threshold' is type 'numeric'
  r2_threshold <- as.numeric(r2_threshold)

  if (!(r2_threshold >= 0 & r2_threshold <= 1))
  {
    stop(paste("R2 threshold must be between 0 and 1: ", r2_threshold, ".", sep=""))
  }
  else if (r2_threshold >= 0 & r2_threshold <= 1)
  {
    # convert character back to numeric
    r2_threshold <- as.character(r2_threshold)
  }

  # ensure 'maf_threshold' is type 'numeric'
  maf_threshold <- as.numeric(maf_threshold)

  if (!(maf_threshold >= 0 & maf_threshold <= 1))
  {
    stop(paste("MAF threshold must be between 0 and 1: ", maf_threshold, ".", sep=""))
  }
  else if (maf_threshold >= 0 & maf_threshold <= 1)
  {
    # convert character back to numeric
    maf_threshold <- as.character(maf_threshold)
  }

  if(is.null(token)) {
    stop("Enter valid access token. Please register using the LDlink API Access tab: https://ldlink.nci.nih.gov/?tab=apiaccess")
  }

  if(!(is.character(file) | file == FALSE)) {
    stop("Invalid input for file option.")
  }

  # Ensure input for 'genome_build' is valid.
  if(length(genome_build) > 1) {
    stop("Invalid input.  Please choose only one available genome build.")
  }

  if(!(all(genome_build %in% avail_genome_build))) {
    stop("Not an available genome build.")
  }

# Request body
snps_to_upload <- paste(unlist(snps), collapse = "\n")
pop_to_upload <- paste(unlist(pop), collapse = "+")
jsonbody <- list(snps = snps_to_upload,
                 pop = pop_to_upload,
                 r2_threshold = r2_threshold,
                 maf_threshold = maf_threshold,
                 genome_build = genome_build)

# URL string
url_str <- paste(url, "?", "&token=", token, sep="")

# before full 'POST command', check if LDlink server is up and accessible...
# if server is down pkg should fail gracefully with informative message (not error)
r_url <- httr::POST(url)
if (httr::http_error(r_url)) { # if server is down use message (and not an error)
  message("The LDlink server is down or not accessible. Please try again later.")
  return(NULL)
  # if server is working then proceed
} else {
  message("\nLDlink server is working...\n")
}

# POST command
raw_out <-  httr::POST(url=url_str, body=jsonbody, encode="json")
httr::stop_for_status(raw_out)
# Parse response object
data_out <- read.delim(textConnection(httr::content(raw_out, "text", encoding = "UTF-8")), header=T, sep="\t")

# Replace any number of '.' in column names with '_'
names(data_out) <- gsub(x = names(data_out),
                        pattern = "(\\.)+",
                        replacement = "_")

# Check for error/warnings in response data
  if(grepl("error", data_out[nrow(data_out),1], ignore.case = TRUE)) {
    stop(data_out[nrow(data_out),1])
  }

  if(grepl("warning", data_out[nrow(data_out),1], ignore.case = TRUE)) {
    stop(data_out[nrow(data_out),1])
  }

# Evaluate 'file' option
  if (file == FALSE) {
    return(data_out)
  } else if (is.character(file)) {
    print(data_out)
    write.table(data_out, file = file, quote = F, row.names = F, sep = "\t")
    cat(paste("\nFile saved to ",file,".", sep=""))
    return(data_out)
  }

}
############ End Primary Function ##################
