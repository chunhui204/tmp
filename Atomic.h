#pragma once
#include <atomic>
#include <functional>
#include "MutexLock.h"
#include "Condition.h"""

const int kSize = 1024;

namespace atomic
{
class RDLock
{
public:
	RDLock()
		: writerCond_(mutex_)
		, readerCond_(mutex_)
	{
		
	}
	
private:
	std::atomic_int writerCount_ = 0;
	std::atomic_int readerCount_ = 0;
	std::atomic_bool isWriting_ = false;
	std::atomic_bool isReading_ = false;
	MutexLock mutex_;
	Condition writerCond_;
	Condition readerCond_;
};
}