#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <substrate.h>

static ptrdiff_t sTerrOffset  = -1;
static ptrdiff_t sResOffset   = -1;
static Class     sPlayerClass = nil;

static void ResolveOffsets(void) {
    sPlayerClass = objc_getClass("TIOPlayer");
    if (!sPlayerClass) {
        unsigned int n = 0;
        Class *all = objc_copyClassList(&n);
        for (unsigned int i = 0; i < n; i++) {
            if (class_respondsToSelector(all[i], @selector(updateTerritoryCount:))) {
                sPlayerClass = all[i];
                break;
            }
        }
        free(all);
    }
    if (sPlayerClass) {
        Ivar iv_terr = class_getInstanceVariable(sPlayerClass, "_territoryCount");
        Ivar iv_res  = class_getInstanceVariable(sPlayerClass, "_resources");
        if (iv_terr) sTerrOffset = ivar_getOffset(iv_terr);
        if (iv_res)  sResOffset  = ivar_getOffset(iv_res);
    }
}

typedef void (*SetTerrIMP)(id, SEL, NSInteger);
static SetTerrIMP orig_setTerritoryCount = NULL;

static void hook_setTerritoryCount(id self, SEL _cmd, NSInteger val) {
    if (sTerrOffset >= 0) {
        NSInteger *field = (NSInteger *)((uint8_t *)(__bridge void *)self + sTerrOffset);
        if (val < *field) val = *field;
    }
    orig_setTerritoryCount(self, _cmd, val);
}

static const NSInteger kResourcePeg = 999999;

typedef void (*TickResIMP)(id, SEL);
static TickResIMP orig_tickResources = NULL;

static void hook_tickResources(id self, SEL _cmd) {
    orig_tickResources(self, _cmd);
    if (sResOffset >= 0) {
        NSInteger *field = (NSInteger *)((uint8_t *)(__bridge void *)self + sResOffset);
        *field = kResourcePeg;
    }
}

__attribute__((constructor))
static void TIOHackInit(void) {
    ResolveOffsets();
    if (!sPlayerClass) return;

    Method m_terr = class_getInstanceMethod(sPlayerClass, @selector(setTerritoryCount:));
    if (m_terr) {
        orig_setTerritoryCount = (SetTerrIMP)method_getImplementation(m_terr);
        method_setImplementation(m_terr, (IMP)hook_setTerritoryCount);
    }

    Method m_res = class_getInstanceMethod(sPlayerClass, @selector(tickResources));
    if (m_res) {
        orig_tickResources = (TickResIMP)method_getImplementation(m_res);
        method_setImplementation(m_res, (IMP)hook_tickResources);
    }
}

__attribute__((destructor))
static void TIOHackFini(void) {
    if (!sPlayerClass) return;

    if (orig_tickResources) {
        Method m = class_getInstanceMethod(sPlayerClass, @selector(tickResources));
        if (m) method_setImplementation(m, (IMP)orig_tickResources);
    }
    if (orig_setTerritoryCount) {
        Method m = class_getInstanceMethod(sPlayerClass, @selector(setTerritoryCount:));
        if (m) method_setImplementation(m, (IMP)orig_setTerritoryCount);
    }
}
