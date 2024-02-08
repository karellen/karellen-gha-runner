#!/bin/bash -eEu

case "${RUNNER_ARCH}" in
  [Xx]64)
    echo amd64
    ;;

  [Aa][Rr][Mm]64)
    echo arm64
    ;;
  *)
    exit 1
    ;;
esac
