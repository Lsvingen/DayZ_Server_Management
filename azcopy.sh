#!/bin/bash
export AZCOPY_AUTO_LOGIN_TYPE=MSI
azcopy copy "https://tempsoftshare01.blob.core.windows.net/steamaccount2fafiles/maFiles/*" "/opt/steamguard-files/" || true