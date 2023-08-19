#include "prototype.h"


#define LOG(level, format, ...) \
        printfk("%s:%s:%d:%s(): " format "\n", \
            level, __FILE__, __LINE__,__func__, ##__VA_ARGS__ )

#define DEBUG "Debug"

//#if defined(DEBUG)
#define k_debug(format, ...) LOG(DEBUG,format,##__VA_ARGS__)
//#endif

