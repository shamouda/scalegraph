#ifndef __ORG_SCALEGRAPH_IO_FORMAT_HEADER_H
#define __ORG_SCALEGRAPH_IO_FORMAT_HEADER_H

namespace org { namespace scalegraph { namespace io {

struct NativeHeader {
	int8_t magic[4];
	int8_t version;
	int8_t datatype[3];
	int64_t seclen[4];
} ;

}}} // namespace org { namespace scalegraph { namespace io {

#endif // __ORG_SCALEGRAPH_IO_FORMAT_HEADER_H
