#' One-hot like encoding for a 5-mer DNA string
#' @param dna_strings Character vector of 5-mers (A/T/C/G only).
#' @return A data.frame of 5 factor columns nt_pos1..nt_pos5 (levels A,T,C,G).
#' @export
dna_encoding <- function(dna_strings){
  stopifnot(length(dna_strings) >= 1L)
  nn <- nchar(dna_strings[1]); stopifnot(nn == 5L)
  seq_m <- matrix(unlist(strsplit(toupper(dna_strings), "")), ncol = nn, byrow = TRUE)
  if (any(!seq_m %in% c("A","T","C","G"))) stop("dna_strings must contain only A/T/C/G.")
  colnames(seq_m) <- paste0("nt_pos", 1:nn)
  seq_df <- as.data.frame(seq_m, stringsAsFactors = FALSE)
  seq_df[] <- lapply(seq_df, factor, levels = c("A","T","C","G"))
  seq_df
}

#' Batch m6A prediction
#' @description Predict probabilities and labels for multiple rows.
#' @param model A fitted randomForest model (read via \code{readRDS(system.file(...))}).
#' @param df A data.frame with columns:
#'   gc_content, RNA_type, RNA_region, exon_length, distance_to_junction,
#'   evolutionary_conservation, DNA_5mer.
#' @param threshold Numeric between 0 and 1; default 0.5.
#' @return Input \code{df} with added columns \code{predicted_m6A_prob} and \code{predicted_m6A_status}.
#' @examples
#' rf <- readRDS(system.file("extdata","rf_fit.rds", package = "m6APrediction"))
#' path <- system.file("extdata","m6A_input_example.csv", package = "m6APrediction")
#' ex <- read.csv(path, stringsAsFactors = FALSE)
#' head(prediction_multiple(rf, ex, 0.5))
#' @export
#' @import randomForest
#' @importFrom stats predict
prediction_multiple <- function(model, df, threshold = 0.5){
  req <- c("gc_content","RNA_type","RNA_region","exon_length",
           "distance_to_junction","evolutionary_conservation","DNA_5mer")
  if (!all(req %in% names(df))) {
    stop("Missing required columns: ", paste(setdiff(req, names(df)), collapse = ", "))
  }
  # 因子水平对齐
  allowed_type   <- c("mRNA","lincRNA","lncRNA","pseudogene")
  allowed_region <- c("CDS","intron","3'UTR","5'UTR")
  df$RNA_type   <- factor(df$RNA_type,   levels = allowed_type)
  df$RNA_region <- factor(df$RNA_region, levels = allowed_region)

  enc <- dna_encoding(df$DNA_5mer)
  pred_input <- cbind(df[, c("gc_content","RNA_type","RNA_region","exon_length",
                             "distance_to_junction","evolutionary_conservation")],
                      enc)

  p <- stats::predict(model, newdata = pred_input, type = "prob")[, "Positive"]
  out <- df
  out$predicted_m6A_prob   <- round(p, 3)
  out$predicted_m6A_status <- ifelse(p > threshold, "Positive", "Negative")
  out
}

#' Single-sample m6A prediction
#'
#' @description Predict the probability and label for a single input using a fitted random forest model.
#'
#' @param model A fitted randomForest model (e.g., read via
#'   \code{readRDS(system.file("extdata","rf_fit.rds", package = "m6APrediction"))}).
#' @param five_mer Character; DNA 5-mer using only A/T/C/G.
#' @param threshold Numeric between 0 and 1; decision cutoff (default 0.5).
#' @param gc_content Numeric; GC content of the site.
#' @param RNA_type Character; one of \code{"mRNA"}, \code{"lincRNA"}, \code{"lncRNA"}, \code{"pseudogene"}.
#' @param RNA_region Character; one of \code{"CDS"}, \code{"intron"}, \code{"3'UTR"}, \code{"5'UTR"}.
#' @param exon_length Numeric; exon length.
#' @param distance_to_junction Numeric; distance to the nearest junction.
#' @param evolutionary_conservation Numeric; conservation score.
#'
#' @return A list with \code{prob_1} (numeric probability) and \code{label} (0/1).
#'
#' @examples
#' rf <- readRDS(system.file("extdata","rf_fit.rds", package = "m6APrediction"))
#' prediction_single(rf, "ATCGA", 0.5,
#'   gc_content = 0.6, RNA_type = "mRNA", RNA_region = "CDS",
#'   exon_length = 12, distance_to_junction = 5, evolutionary_conservation = 0.8)
#'
#' @export
prediction_single <- function(model, five_mer, threshold = 0.5,
                              gc_content = 0.5, RNA_type = "mRNA", RNA_region = "CDS",
                              exon_length = 100, distance_to_junction = 10,
                              evolutionary_conservation = 0.5){
  df <- data.frame(
    gc_content = as.numeric(gc_content),
    RNA_type = as.character(RNA_type),
    RNA_region = as.character(RNA_region),
    exon_length = as.numeric(exon_length),
    distance_to_junction = as.numeric(distance_to_junction),
    evolutionary_conservation = as.numeric(evolutionary_conservation),
    DNA_5mer = toupper(as.character(five_mer)),
    stringsAsFactors = FALSE
  )
  res <- prediction_multiple(model, df, threshold)
  prob <- res$predicted_m6A_prob[1]
  list(prob_1 = prob, label = as.integer(prob >= threshold))
}
