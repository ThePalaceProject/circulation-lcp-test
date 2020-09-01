#!/bin/sh

./directory_import \
  --collection-name LCP \
  --collection-type LCP \
  --data-source-name lcp \
  --metadata-format onix \
  --metadata-file /var/tmp/lcp-collection/onix.xml \
  --ebook-directory /var/tmp/lcp-collection \
  --rights-uri http://librarysimplified.org/terms/rights-status

./search_index_refresh