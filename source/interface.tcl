_logo      db 'CaseTcl interpreter  version ',VERSION_STRING,														\n
_copyright db 'Copyright (c) 2016, Scientech LLC',																			\n
_usage     db 'usage: case <source> [output]',																					\n
           db 'optional settings:',																											\n
           db ' -m <limit>         set the limit in kilobytes for the available memory',\n
           db ' -p <limit>         set the maximum allowed number of passes',						\n
           db ' -d <name>=<value>  define symbolic variable',														\n
           db ' -s <file>          dump symbolic information for debugging',						\n
           db 0

_memory_prefix    db '  ('										,0
_memory_suffix    db ' kilobytes memory)',\n	,0
_passes_suffix    db ' passes, '							,0
_seconds_suffix   db ' seconds, '							,0
_bytes_suffix     db ' bytes.',\n							,0
#error_prefix      db 'error: '								,0
#error_suffix      db '.'
#cr_lf             db \n												,0
#line_number_start db ' ['											,0
#line_data_start   db ':',\n										,0
