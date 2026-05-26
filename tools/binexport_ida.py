import sys

import ida_auto
import idc


def main():
    args = getattr(idc, "ARGV", [])
    output = args[1] if len(args) > 1 else sys.argv[1]
    ida_auto.auto_wait()
    escaped = output.replace("\\", "\\\\").replace('"', '\\"')
    idc.eval_idc('BinExportBinary("{}");'.format(escaped))
    idc.qexit(0)


main()
