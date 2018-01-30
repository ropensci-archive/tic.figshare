add_package_checks()

get_stage("deploy") %>%
  add_code_step(
    pkgbuild::build(dest_path = "."),
    prepare_call = remotes::install_github("r-lib/pkgbuild")
  )

if (Sys.getenv("FIGSHARE_API") != "") {
  # Other example criteria:
  # - `inherits(ci(), "TravisCI")`: Only for Travis CI
  # - `ci()$is_tag()`: Only for tags, not for branches
  # - `Sys.getenv("BUILD_PKGDOWN") != ""`: If the env var "BUILD_PKGDOWN" is set
  # - `Sys.getenv("TRAVIS_EVENT_TYPE") == "cron"`: Only for Travis cron jobs
  get_stage("deploy") %>%
    add_code_step(
      {
        library(magrittr)
        api_key <-
          Sys.getenv("FIGSHARE_API") %>%
          base64enc::base64decode() %>%
          memDecompress("gzip") %>%
          unserialize()

        id <- rfigshare::fs_create(
          title = unname(desc::desc_get("Title")),
          description = unname(desc::desc_get("Description")),
          type = "fileset",
          session = api_key
        )
        if (!is.numeric(id)) {
          httr::stop_for_status(id, "create article")
        }
        message("Created article ", id)

        # Workaround for ropenscilabs/tic#38
        path <- dir(pattern = glob2rx("*.tar.gz"))[[1]]

        rfigshare::fs_upload(id, path, session = api_key)
        message("Uploaded ", path, " to article ", id)

        # Normally you want to review an article before making it public,
        # we don't for this example:
        rfigshare::fs_add_categories(id, "Ecology", session = api_key)
        rfigshare::fs_make_public(id, session = api_key)
      },
      # Needs rfigshare > 0.3.7
      prepare_call = remotes::install_github("ropensci/rfigshare")
    )
}
