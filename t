diff --git a/Common.Windows b/Common.Windows
index 6f944cf..2f6abb1 100644
--- a/Common.Windows
+++ b/Common.Windows
@@ -29,13 +29,14 @@ BUILD_DIR = $(TOP_DIR)/gv-build
 # Options for compiler + linker:
 #
 USE_CRT_DEBUG      ?= 0
-USE_MP_COMPILE     ?= 1
+USE_MP_COMPILE     ?= 0
 USE_CLANG_CL       ?= 0
 USE_CLANG_FORMATER ?= 1
 USE_GOOGLE_TEST    ?= 0
 USE_VECTORCALL     ?= 0
 USE_XML2           ?= 1
 USE_ZLIB           ?= 1
+USE_CHECK_LIBS     ?= 1
 
 ifeq ($(USE_CRT_DEBUG),1)
   D = d
@@ -54,7 +55,7 @@ default: all
 #   set(LLVM_VERSION_MINOR 0)
 #   set(LLVM_VERSION_PATCH 0)
 #
-VER_MAJOR = 10
+VER_MAJOR = 12
 VER_MINOR = 0
 VER_MICRO = 0
 VERSION   = $(VER_MAJOR).$(VER_MINOR).$(VER_MICRO)-Win32
@@ -94,6 +95,16 @@ ICONV_LIB = $(ICONV_ROOT)/lib/libiconvStatic$(D).lib
 #
 XML2_LIB = $(XML2_ROOT)/xml2$(D).lib
 
+#
+# TODO: Rewrite into:
+#
+ifeq ($(NEED_XML2),1)
+  CFLAGS += -I$(XML2_ROOT)/include  \
+            -I$(ICONV_ROOT)/include \
+            -DLIBXML_STATIC
+endif
+
+
 #
 # 'LLVM_ENABLE_DIA_SDK = 1' in below generated 'llvm-config.h'.
 #
@@ -118,6 +129,7 @@ BRIGHT_WHITE  = \e[1;37m
 
 colour_msg = @echo -e "$(1)\e[0m"
 green_msg  = $(call colour_msg,$(BRIGHT_GREEN)$(strip $(1)))
+white_msg  = $(call colour_msg,$(BRIGHT_WHITE)$(strip $(1)))
 yellow_msg = $(call colour_msg,$(BRIGHT_YELLOW)$(strip $(1)))
 
 define Warning
@@ -307,7 +319,7 @@ c_to_i     = $(notdir $(1:.c=.i))
 # Mainly used in the C/C++ preprocess rule below.
 # And also in 'llvm/tools/llvm-config/Makefile.Windows'.
 #
-PYTHON ?= python
+PYTHON ?= py -3
 
 GENERATED += dirs
 
@@ -320,6 +332,7 @@ GENERATED += $(CXX).args                                        \
              $(TOP_DIR)/llvm/include/llvm/Config/llvm-config.h
 
 $(CXX).args: $(THIS_FILE) $(TOP_DIR)/Common.Windows
+	$(call green_msg, Generating $@)
 	$(call create_rsp_file, $@, -c $(CFLAGS))
 
 $(OBJ_DIR)/%.obj: %.cpp $(MDEPEND)
@@ -1245,6 +1258,14 @@ realclean vclean: clean
 	        $(sort $(TARGETS:.exe=.map) $(TARGETS:.dll=.map) \
 	               $(TARGETS:.exe=.pdb) $(TARGETS:.dll=.pdb))
 
+#
+# Use this Python script to check a .map-files for unused libraries after
+# a successful 'link' done in '$(call link_EXE ...)' or '$(call link_DLL ...)'.
+#
+ifeq ($(USE_CHECK_LIBS),1)
+  check_for_unused_libs = $(PYTHON) $(TOP_DIR)/check-for-unused-libs.py $(1)
+endif
+
 #
 # Macro to create an EXE from objects.
 # Syntax: $(call link_EXE, ...):
@@ -1256,6 +1277,8 @@ define link_EXE
   $(call create_rsp_file, link.args, $(LDFLAGS) $(2))
   link -out:$(strip $(1)) @link.args > link.tmp
   @cat link.tmp >> $(1:.exe=.map)
+  $(call check_for_unused_libs, link.tmp)
+  $(call white_msg, Done.\n)
   @rm -f link.tmp
 endef
 
@@ -1271,6 +1294,8 @@ define link_DLL
   $(call create_rsp_file, link.args, $(LDFLAGS) $(3))
   link -dll -out:$(strip $(1)) -implib:$(strip $(2)) @link.args > link.tmp
   @cat link.tmp >> $(1:.dll=.map)
+  $(call check_for_unused_libs, link.tmp)
+  $(call white_msg, Done.\n)
   @rm -f $(2:.lib=.exp) link.tmp
 endef
 
@@ -1304,6 +1329,7 @@ endef
 #
 define create_lib
   $(call colour_msg,Creating $(BRIGHT_GREEN)$(strip $(1)))
+  @rm -f $(1)
   lib -nologo -out:$(strip $(1)) $(2)
   @echo
   $(call create_lib_list_CPP_0, $(1:.lib=.list), $(1))
@@ -1762,21 +1788,15 @@ $(TOP_DIR)/llvm/include/llvm/IR/Attributes.inc: $(TOP_DIR)/llvm/include/llvm/IR/
 $(TOP_DIR)/llvm/lib/IR/AttributesCompatFunc.inc: $(TOP_DIR)/llvm/include/llvm/IR/Attributes.td $(INC_DEPS)
 	$(call llvm_tblgen, $@, -gen-attrs $<)
 
-# $(TOP_DIR)/llvm/lib/IR/AttributesCompatFunc.inc: $(TOP_DIR)/llvm/include/llvm/IR/AttributesCompatFunc.td $(TOP_DIR)/llvm/include/llvm/IR/Attributes.td $(INC_DEPS)
-#	$(call llvm_tblgen, $@, -gen-attrs $<)
-
 $(TOP_DIR)/llvm/include/llvm/IR/IntrinsicEnums.inc: $(TOP_DIR)/llvm/include/llvm/IR/Intrinsics.td $(INC_DEPS)
 	$(call llvm_tblgen, $@, -gen-intrinsic-enums $<)
 
-$(TOP_DIR)/llvm/include/llvm/IR/IntrinsicImpl.inc: $(INC_DEPS)
+$(TOP_DIR)/llvm/include/llvm/IR/IntrinsicImpl.inc: $(TOP_DIR)/llvm/include/llvm/IR/Intrinsics.td $(INC_DEPS)
 	$(call llvm_tblgen, $@, -gen-intrinsic-impl $<)
 
 $(TOP_DIR)/llvm/include/llvm/IR/IntrinsicsARM.h: $(TOP_DIR)/llvm/include/llvm/IR/Intrinsics.td $(INC_DEPS)
 	$(call llvm_tblgen, $@, -gen-intrinsic-enums -intrinsic-prefix=arm $<)
 
-$(TOP_DIR)/llvm/include/llvm/IR/IntrinsicsX86.h: $(TOP_DIR)/llvm/include/llvm/IR/Intrinsics.td $(INC_DEPS)
-	$(call llvm_tblgen, $@, -gen-intrinsic-enums -intrinsic-prefix=x86 $<)
-
 $(TOP_DIR)/llvm/include/llvm/IR/IntrinsicsAArch64.h: $(TOP_DIR)/llvm/include/llvm/IR/Intrinsics.td $(INC_DEPS)
 	$(call llvm_tblgen, $@, -gen-intrinsic-enums -intrinsic-prefix=aarch64 $<)
 
@@ -1810,6 +1830,9 @@ $(TOP_DIR)/llvm/include/llvm/IR/IntrinsicsS390.h: $(TOP_DIR)/llvm/include/llvm/I
 $(TOP_DIR)/llvm/include/llvm/IR/IntrinsicsWebAssembly.h: $(TOP_DIR)/llvm/include/llvm/IR/Intrinsics.td $(INC_DEPS)
 	$(call llvm_tblgen, $@, -gen-intrinsic-enums -intrinsic-prefix=wasm $<)
 
+$(TOP_DIR)/llvm/include/llvm/IR/IntrinsicsX86.h: $(TOP_DIR)/llvm/include/llvm/IR/Intrinsics.td $(INC_DEPS)
+	$(call llvm_tblgen, $@, -gen-intrinsic-enums -intrinsic-prefix=x86 $<)
+
 $(TOP_DIR)/llvm/include/llvm/IR/IntrinsicsXCore.h: $(TOP_DIR)/llvm/include/llvm/IR/Intrinsics.td $(INC_DEPS)
 	$(call llvm_tblgen, $@, -gen-intrinsic-enums -intrinsic-prefix=xcore $<)
 
@@ -1910,7 +1933,7 @@ define LLVM_RC_COMMON
   #endif
 
   #ifndef RC_FILETYPE
-  #error "Add a '-DRC_FILETYPE' before including me."
+  #error "Add a '-DRC_FILETYPE=[VFT_APP|VFT_DLL]' before including me."
   #endif
 
   #ifndef RC_DESCRIPTION
@@ -1921,10 +1944,10 @@ define LLVM_RC_COMMON
   #define RC_COMMENT_EXTRA ""
   #endif
 
-  #if (RC_DEBUG_RELEASE == 1)
-    #define RC_DEBUG_RELEASE_STR  "debug"
+  #if ($(USE_CRT_DEBUG) == 1)
+    #define RC_DEBUG_RELEASE_STR  "debug"      // 'USE_CRT_DEBUG = 1'
   #else
-    #define RC_DEBUG_RELEASE_STR  "release"
+    #define RC_DEBUG_RELEASE_STR  "release"    // 'USE_CRT_DEBUG = 1'
   #endif
 
   VS_VERSION_INFO VERSIONINFO
@@ -1976,7 +1999,7 @@ DEP_REPLACE = -e 's|$(TOP_DIR)/llvm/include/llvm/Config/abi-breaking.h||' \
 
 DEP_REPLACE += -e 's|\(.*\)\.o: |\n$$(OBJ_DIR)\/\1.obj: |'
 
-DEP_CFLAGS  = -MM -std=c++1y $(filter -I% -D%, $(CFLAGS) $(EXTRA_CFLAGS))
+DEP_CFLAGS = -MM -std=c++1y $(filter -I% -D%, $(CFLAGS) $(EXTRA_CFLAGS))
 
 depend: $(OBJ_DIR) $(GENERATED)
 	$(call Generating, .depend.Windows, #)
diff --git a/clang/include/clang/Makefile.Windows b/clang/include/clang/Makefile.Windows
index b0a5ff1..1173319 100644
--- a/clang/include/clang/Makefile.Windows
+++ b/clang/include/clang/Makefile.Windows
@@ -33,6 +33,7 @@ INC_FILES += $(addprefix Basic/,                \
                arm_mve_builtin_cg.inc           \
                arm_mve_builtin_sema.inc         \
                arm_neon.inc                     \
+               arm_sve_sema_rangechecks.inc     \
                AttrList.inc                     \
                AttrSubMatchRulesList.inc        \
                AttrHasAttributeImpl.inc         \
@@ -92,7 +93,6 @@ all: $(GENERATED)
 $(INC_FILES):       $(BUILD_DIR)/bin/clang-tblgen.exe $(MDEPEND)
 Driver/Options.inc: $(BUILD_DIR)/bin/llvm-tblgen.exe  $(MDEPEND)
 
-
 AST/AbstractBasicReader.inc: AST/PropertiesBase.td
 	$(call clang_tblgen, $@, -gen-clang-basic-reader $<)
 
@@ -171,6 +171,9 @@ Basic/arm_mve_builtin_sema.inc: Basic/arm_mve.td
 Basic/arm_neon.inc: Basic/arm_neon.td
 	$(call clang_tblgen, $@, -gen-arm-neon-sema -I./Basic $<)
 
+Basic/arm_sve_sema_rangechecks.inc: Basic/arm_sve.td
+	$(call clang_tblgen, $@, -gen-arm-sve-sema-rangechecks -I./Basic $<)
+
 Basic/AttrList.inc: Basic/Attr.td
 	$(call clang_tblgen, $@, -gen-clang-attr-list -I./Basic $<)
 
@@ -278,7 +281,7 @@ StaticAnalyzer/Checkers/Checkers.inc: StaticAnalyzer/Checkers/Checkers.td
 
 #######################################################################################
 
-Basic/Version.inc: $(MDEPEND)
+Basic/Version.inc: $(THIS_FILE)
 	$(call Generating, $@, //)
 	$(file >> $@,$(Basic_Version_INC))
 
@@ -290,7 +293,7 @@ define Basic_Version_INC
   #define CLANG_VERSION_PATCHLEVEL $(VER_MICRO)
 endef
 
-Config/config.h: $(MDEPEND)
+Config/config.h: $(THIS_FILE)
 	$(call Generating, $@, //)
 	$(file >> $@,$(clang_config_H))
 
@@ -304,8 +307,10 @@ define clang_config_H
   #define CLANG_DEFAULT_LINKER                ""
   #define CLANG_DEFAULT_CXX_STDLIB            ""
   #define CLANG_DEFAULT_RTLIB                 ""
+  #define CLANG_DEFAULT_UNWINDLIB             "none"
   #define CLANG_DEFAULT_OBJCOPY               "objcopy"
   #define CLANG_DEFAULT_OPENMP_RUNTIME        "libomp"
+  #define CLANG_SYSTEMZ_DEFAULT_ARCH          "z10"
   #define CLANG_OPENMP_NVPTX_DEFAULT_ARCH     "sm_35"
   #define CLANG_LIBDIR_SUFFIX                  ""
   #define CLANG_RESOURCE_DIR                   ""
diff --git a/clang/lib/Analysis/Makefile.Windows b/clang/lib/Analysis/Makefile.Windows
index b212900..37019b8 100644
--- a/clang/lib/Analysis/Makefile.Windows
+++ b/clang/lib/Analysis/Makefile.Windows
@@ -9,13 +9,46 @@ include $(TOP_DIR)/Common.Windows
 #
 # .inc-files needed here:
 #
-INC_FILES = $(CLANG_INCLUDE_DIR)/AST/Attrs.inc              \
-            $(CLANG_INCLUDE_DIR)/AST/AttrVisitor.inc        \
-            $(CLANG_INCLUDE_DIR)/AST/CommentCommandList.inc \
-            $(CLANG_INCLUDE_DIR)/AST/DeclNodes.inc          \
-            $(CLANG_INCLUDE_DIR)/AST/StmtNodes.inc          \
-            $(CLANG_INCLUDE_DIR)/AST/TypeNodes.inc          \
-            $(CLANG_INCLUDE_DIR)/Basic/AttrList.inc
+INC_FILES = $(addprefix $(CLANG_INCLUDE_DIR)/AST/,    \
+              AbstractBasicReader.inc                 \
+              AbstractBasicWriter.inc                 \
+              AbstractTypeReader.inc                  \
+              AbstractTypeWriter.inc                  \
+              AttrImpl.inc                            \
+              AttrNodeTraverse.inc                    \
+              Attrs.inc                               \
+              AttrTextNodeDump.inc                    \
+              AttrVisitor.inc                         \
+              CommentCommandInfo.inc                  \
+              CommentCommandList.inc                  \
+              CommentHTMLNamedCharacterReferences.inc \
+              CommentHTMLTags.inc                     \
+              CommentHTMLTagsProperties.inc           \
+              CommentNodes.inc                        \
+              DeclNodes.inc                           \
+              StmtDataCollectors.inc                  \
+              StmtNodes.inc                           \
+              TypeNodes.inc)                          \
+                                                      \
+            $(addprefix $(CLANG_INCLUDE_DIR)/Basic/,  \
+              AttrHasAttributeImpl.inc                \
+              AttrList.inc                            \
+              AttrSubMatchRulesList.inc               \
+              DiagnosticAnalysisKinds.inc             \
+              DiagnosticASTKinds.inc                  \
+              DiagnosticCommentKinds.inc              \
+              DiagnosticCommonKinds.inc               \
+              DiagnosticCrossTUKinds.inc              \
+              DiagnosticDriverKinds.inc               \
+              DiagnosticFrontendKinds.inc             \
+              DiagnosticGroups.inc                    \
+              DiagnosticIndexName.inc                 \
+              DiagnosticLexKinds.inc                  \
+              DiagnosticParseKinds.inc                \
+              DiagnosticRefactoringKinds.inc          \
+              DiagnosticSemaKinds.inc                 \
+              DiagnosticSerializationKinds.inc        \
+              Version.inc)
 
 LIB_SRC = AnalysisDeclContext.cpp     \
           BodyFarm.cpp                \
diff --git a/clang/lib/Basic/Makefile.Windows b/clang/lib/Basic/Makefile.Windows
index 4110816..dab5442 100644
--- a/clang/lib/Basic/Makefile.Windows
+++ b/clang/lib/Basic/Makefile.Windows
@@ -44,6 +44,7 @@ LIB_SRC = Attributes.cpp               \
           Diagnostic.cpp               \
           DiagnosticIDs.cpp            \
           DiagnosticOptions.cpp        \
+          ExpressionTraits.cpp         \
           FileManager.cpp              \
           FileSystemStatCache.cpp      \
           FixedPoint.cpp               \
@@ -63,6 +64,7 @@ LIB_SRC = Attributes.cpp               \
           TargetInfo.cpp               \
           Targets.cpp                  \
           TokenKinds.cpp               \
+          TypeTraits.cpp               \
           Version.cpp                  \
           Warnings.cpp                 \
           XRayInstr.cpp                \
@@ -89,6 +91,7 @@ LIB_SRC += $(addprefix Targets/, \
              Sparc.cpp           \
              SystemZ.cpp         \
              TCE.cpp             \
+             VE.cpp              \
              WebAssembly.cpp     \
              X86.cpp             \
              XCore.cpp)
diff --git a/clang/lib/CodeGen/Makefile.Windows b/clang/lib/CodeGen/Makefile.Windows
index ded74ce..3a2b943 100644
--- a/clang/lib/CodeGen/Makefile.Windows
+++ b/clang/lib/CodeGen/Makefile.Windows
@@ -4,6 +4,12 @@
 TOP_DIR = ../../..
 TARGETS = $(BUILD_DIR)/lib/clangCodeGen.lib
 
+#
+# Because of:
+#  fatal error C1060: compiler is out of heap space (compiling source file CodeGenPGO.cpp)
+#
+USE_CLANG_CL = 1
+
 include $(TOP_DIR)/Common.Windows
 
 #
@@ -43,6 +49,8 @@ LIB_SRC = BackendUtil.cpp                      \
           CGObjCRuntime.cpp                    \
           CGOpenCLRuntime.cpp                  \
           CGOpenMPRuntime.cpp                  \
+          CGOpenMPRuntimeAMDGCN.cpp            \
+          CGOpenMPRuntimeGPU.cpp               \
           CGOpenMPRuntimeNVPTX.cpp             \
           CGRecordLayoutBuilder.cpp            \
           CGStmt.cpp                           \
diff --git a/clang/lib/Driver/Makefile.Windows b/clang/lib/Driver/Makefile.Windows
index 9505043..6e8b151 100644
--- a/clang/lib/Driver/Makefile.Windows
+++ b/clang/lib/Driver/Makefile.Windows
@@ -5,14 +5,13 @@ TOP_DIR = ../../..
 TARGETS = $(BUILD_DIR)/lib/clangDriver.lib
 VPATH   = ToolChains ToolChains/Arch
 
-EXTRA_CFLAGS = -DCLANG_DEFAULT_UNWINDLIB=\"none\"
-
 include $(TOP_DIR)/Common.Windows
 
 #
 # .inc-files needed here:
 #
-INC_FILES = $(CLANG_INCLUDE_DIR)/Basic/DiagnosticCommonKinds.inc
+INC_FILES = $(CLANG_INCLUDE_DIR)/Basic/DiagnosticCommonKinds.inc \
+            $(CLANG_INCLUDE_DIR)/Config/config.h
 
 LIB_SRC = Action.cpp        \
           Compilation.cpp   \
@@ -68,6 +67,7 @@ LIB_SRC += $(addprefix ToolChains/, \
              RISCVToolchain.cpp     \
              Solaris.cpp            \
              TCE.cpp                \
+             VEToolChain.cpp        \
              WebAssembly.cpp        \
              XCore.cpp)
 
@@ -79,13 +79,14 @@ LIB_SRC += $(addprefix ToolChains/Arch/, \
              RISCV.cpp                   \
              Sparc.cpp                   \
              SystemZ.cpp                 \
+             VE.cpp                      \
              X86.cpp)
 
 ALL_SOURCES = $(LIB_SRC)
 
 LIB_OBJ = $(call cpp_to_obj, $(LIB_SRC))
 
-all: $(GENERATED) $(INC_FILES) $(TARGETS)
+all: $(GENERATED) inc_files $(TARGETS)
 
 ifeq ($(USE_MP_COMPILE),1)
 $(LIB_OBJ): $(LIB_SRC)
@@ -95,7 +96,7 @@ endif
 $(BUILD_DIR)/lib/clangDriver.lib: $(LIB_OBJ)
 	 $(call create_lib, $@, $^)
 
-$(INC_FILES):
+inc_files::
 	$(call do_make, $(CLANG_INCLUDE_DIR), all)
 
 -include .depend.Windows
diff --git a/clang/lib/Sema/Makefile.Windows b/clang/lib/Sema/Makefile.Windows
index cfd2967..dcc8ec3 100644
--- a/clang/lib/Sema/Makefile.Windows
+++ b/clang/lib/Sema/Makefile.Windows
@@ -7,10 +7,11 @@ TARGETS = $(BUILD_DIR)/lib/clangSema.lib
 include $(TOP_DIR)/Common.Windows
 
 #
-# .inc-files needed here:
+# We need these .inc-files needed here:
 #
 INC_FILES = $(CLANG_INCLUDE_DIR)/Basic/DiagnosticCommonKinds.inc \
-            $(CLANG_INCLUDE_DIR)/Basic/DiagnosticLexKinds.inc
+            $(CLANG_INCLUDE_DIR)/Basic/DiagnosticLexKinds.inc    \
+            $(CLANG_INCLUDE_DIR)/Basic/arm_sve_sema_rangechecks.inc
 
 GENERATED += OpenCLBuiltins.inc
 
@@ -57,6 +58,7 @@ LIB_SRC = AnalysisBasedWarnings.cpp       \
           SemaStmt.cpp                    \
           SemaStmtAsm.cpp                 \
           SemaStmtAttr.cpp                \
+          SemaSYCL.cpp                    \
           SemaTemplate.cpp                \
           SemaTemplateDeduction.cpp       \
           SemaTemplateInstantiate.cpp     \
@@ -69,7 +71,7 @@ ALL_SOURCES = $(LIB_SRC)
 
 LIB_OBJ = $(call cpp_to_obj, $(LIB_SRC))
 
-all: $(GENERATED) $(INC_FILES) $(TARGETS)
+all: $(GENERATED) inc_files $(TARGETS)
 
 ifeq ($(CXX),cl)
   CFLAGS += -bigobj
@@ -83,7 +85,7 @@ endif
 $(BUILD_DIR)/lib/clangSema.lib: $(LIB_OBJ) $(THIS_FILE)
 	 $(call create_lib, $@, $(LIB_OBJ))
 
-$(INC_FILES):
+inc_files:
 	$(call do_make, $(CLANG_INCLUDE_DIR), all)
 
 OpenCLBuiltins.inc: OpenCLBuiltins.td $(BUILD_DIR)/bin/clang-tblgen.exe
diff --git a/clang/lib/StaticAnalyzer/Makefile.Windows b/clang/lib/StaticAnalyzer/Makefile.Windows
index 890e825..e3b33e6 100644
--- a/clang/lib/StaticAnalyzer/Makefile.Windows
+++ b/clang/lib/StaticAnalyzer/Makefile.Windows
@@ -7,228 +7,238 @@ TARGETS = $(BUILD_DIR)/lib/clangStaticAnalyzerCheckers.lib \
           $(BUILD_DIR)/lib/clangStaticAnalyzerFrontend.lib
 
 VPATH = Checkers                     \
-        Chckers/cert                 \
+        Checkers/cert                \
         Checkers/MPI-Checker         \
         Checkers/RetainCountChecker  \
         Checkers/UninitializedObject \
+        Checkers/WebKit              \
         Core                         \
         Frontend
 
 include $(TOP_DIR)/Common.Windows
 
-clangStaticAnalyzerCheckers_SRC = $(addprefix Checkers/,                               \
-                                    AnalysisOrderChecker.cpp                           \
-                                    AnalyzerStatsChecker.cpp                           \
-                                    ArrayBoundChecker.cpp                              \
-                                    ArrayBoundCheckerV2.cpp                            \
-                                    BasicObjCFoundationChecks.cpp                      \
-                                    BlockInCriticalSectionChecker.cpp                  \
-                                    BoolAssignmentChecker.cpp                          \
-                                    BuiltinFunctionChecker.cpp                         \
-                                    CStringChecker.cpp                                 \
-                                    CStringSyntaxChecker.cpp                           \
-                                    CallAndMessageChecker.cpp                          \
-                                    CastSizeChecker.cpp                                \
-                                    CastToStructChecker.cpp                            \
-                                    CastValueChecker.cpp                               \
-                                    CheckObjCDealloc.cpp                               \
-                                    CheckObjCInstMethSignature.cpp                     \
-                                    CheckPlacementNew.cpp                              \
-                                    CheckSecuritySyntaxOnly.cpp                        \
-                                    CheckSizeofPointer.cpp                             \
-                                    CheckerDocumentation.cpp                           \
-                                    ChrootChecker.cpp                                  \
-                                    CloneChecker.cpp                                   \
-                                    ContainerModeling.cpp                              \
-                                    ConversionChecker.cpp                              \
-                                    CXXSelfAssignmentChecker.cpp                       \
-                                    DeadStoresChecker.cpp                              \
-                                    DebugCheckers.cpp                                  \
-                                    DebugContainerModeling.cpp                         \
-                                    DebugIteratorModeling.cpp                          \
-                                    DeleteWithNonVirtualDtorChecker.cpp                \
-                                    DereferenceChecker.cpp                             \
-                                    DirectIvarAssignment.cpp                           \
-                                    DivZeroChecker.cpp                                 \
-                                    DynamicTypePropagation.cpp                         \
-                                    DynamicTypeChecker.cpp                             \
-                                    EnumCastOutOfRangeChecker.cpp                      \
-                                    ExprInspectionChecker.cpp                          \
-                                    FixedAddressChecker.cpp                            \
-                                    FuchsiaHandleChecker.cpp                           \
-                                    GCDAntipatternChecker.cpp                          \
-                                    GenericTaintChecker.cpp                            \
-                                    GTestChecker.cpp                                   \
-                                    IdenticalExprChecker.cpp                           \
-                                    InnerPointerChecker.cpp                            \
-                                    InvalidatedIteratorChecker.cpp                     \
-                                    Iterator.cpp                                       \
-                                    IteratorModeling.cpp                               \
-                                    IteratorRangeChecker.cpp                           \
-                                    IvarInvalidationChecker.cpp                        \
-                                    LLVMConventionsChecker.cpp                         \
-                                    LocalizationChecker.cpp                            \
-                                    MacOSKeychainAPIChecker.cpp                        \
-                                    MacOSXAPIChecker.cpp                               \
-                                    MallocChecker.cpp                                  \
-                                    MallocOverflowSecurityChecker.cpp                  \
-                                    MallocSizeofChecker.cpp                            \
-                                    MismatchedIteratorChecker.cpp                      \
-                                    MmapWriteExecChecker.cpp                           \
-                                    MIGChecker.cpp                                     \
-                                    MoveChecker.cpp                                    \
-                                    NSAutoreleasePoolChecker.cpp                       \
-                                    NSErrorChecker.cpp                                 \
-                                    NoReturnFunctionChecker.cpp                        \
-                                    NonNullParamChecker.cpp                            \
-                                    NonnullGlobalConstantsChecker.cpp                  \
-                                    NullabilityChecker.cpp                             \
-                                    NumberObjectConversionChecker.cpp                  \
-                                    ObjCAtSyncChecker.cpp                              \
-                                    ObjCAutoreleaseWriteChecker.cpp                    \
-                                    ObjCContainersASTChecker.cpp                       \
-                                    ObjCContainersChecker.cpp                          \
-                                    ObjCMissingSuperCallChecker.cpp                    \
-                                    ObjCPropertyChecker.cpp                            \
-                                    ObjCSelfInitChecker.cpp                            \
-                                    ObjCSuperDeallocChecker.cpp                        \
-                                    ObjCUnusedIVarsChecker.cpp                         \
-                                    OSObjectCStyleCast.cpp                             \
-                                    PaddingChecker.cpp                                 \
-                                    PointerArithChecker.cpp                            \
-                                    PointerIterationChecker.cpp                        \
-                                    PointerSortingChecker.cpp                          \
-                                    PointerSubChecker.cpp                              \
-                                    PthreadLockChecker.cpp                             \
-                                    ReturnPointerRangeChecker.cpp                      \
-                                    ReturnUndefChecker.cpp                             \
-                                    ReturnValueChecker.cpp                             \
-                                    RunLoopAutoreleaseLeakChecker.cpp                  \
-                                    SimpleStreamChecker.cpp                            \
-                                    SmartPtrModeling.cpp                               \
-                                    StackAddrEscapeChecker.cpp                         \
-                                    StdLibraryFunctionsChecker.cpp                     \
-                                    STLAlgorithmModeling.cpp                           \
-                                    StreamChecker.cpp                                  \
-                                    Taint.cpp                                          \
-                                    TaintTesterChecker.cpp                             \
-                                    TestAfterDivZeroChecker.cpp                        \
-                                    TraversalChecker.cpp                               \
-                                    TrustNonnullChecker.cpp                            \
-                                    UndefBranchChecker.cpp                             \
-                                    UndefCapturedBlockVarChecker.cpp                   \
-                                    UndefResultChecker.cpp                             \
-                                    UndefinedArraySubscriptChecker.cpp                 \
-                                    UndefinedAssignmentChecker.cpp                     \
-                                    UninitializedObject/UninitializedObjectChecker.cpp \
-                                    UninitializedObject/UninitializedPointee.cpp       \
-                                    UnixAPIChecker.cpp                                 \
-                                    UnreachableCodeChecker.cpp                         \
-                                    VforkChecker.cpp                                   \
-                                    VLASizeChecker.cpp                                 \
-                                    ValistChecker.cpp                                  \
-                                    VirtualCallChecker.cpp)
-
-clangStaticAnalyzerCheckers_SRC += Checkers/cert/PutenvWithAutoChecker.cpp
-
-clangStaticAnalyzerCheckers_SRC += $(addprefix Checkers/MPI-Checker/, \
-                                     MPIBugReporter.cpp               \
-                                     MPIChecker.cpp                   \
-                                     MPIFunctionClassifier.cpp)
-
-clangStaticAnalyzerCheckers_SRC += $(addprefix Checkers/RetainCountChecker/, \
-                                     RetainCountChecker.cpp                  \
-                                     RetainCountDiagnostics.cpp)
-
-clangStaticAnalyzerCheckers_SRC += $(addprefix Checkers/UninitializedObject/, \
-                                     UninitializedObjectChecker.cpp           \
-                                     UninitializedPointee.cpp)
-
-clangStaticAnalyzerCore_SRC = $(addprefix Core/,            \
-                                APSIntType.cpp              \
-                                AnalysisManager.cpp         \
-                                AnalyzerOptions.cpp         \
-                                BasicValueFactory.cpp       \
-                                BlockCounter.cpp            \
-                                BugReporter.cpp             \
-                                BugReporterVisitors.cpp     \
-                                CallEvent.cpp               \
-                                Checker.cpp                 \
-                                CheckerContext.cpp          \
-                                CheckerHelpers.cpp          \
-                                CheckerManager.cpp          \
-                                CommonBugCategories.cpp     \
-                                ConstraintManager.cpp       \
-                                CoreEngine.cpp              \
-                                DynamicSize.cpp             \
-                                DynamicType.cpp             \
-                                Environment.cpp             \
-                                ExplodedGraph.cpp           \
-                                ExprEngine.cpp              \
-                                ExprEngineC.cpp             \
-                                ExprEngineCXX.cpp           \
-                                ExprEngineCallAndReturn.cpp \
-                                ExprEngineObjC.cpp          \
-                                FunctionSummary.cpp         \
-                                HTMLDiagnostics.cpp         \
-                                IssueHash.cpp               \
-                                LoopUnrolling.cpp           \
-                                LoopWidening.cpp            \
-                                MemRegion.cpp               \
-                                PlistDiagnostics.cpp        \
-                                ProgramState.cpp            \
-                                RangeConstraintManager.cpp  \
-                                RangedConstraintManager.cpp \
-                                RegionStore.cpp             \
-                                SarifDiagnostics.cpp        \
-                                SimpleConstraintManager.cpp \
-                                SimpleSValBuilder.cpp       \
-                                SMTConstraintManager.cpp    \
-                                Store.cpp                   \
-                                SubEngine.cpp               \
-                                SValBuilder.cpp             \
-                                SVals.cpp                   \
-                                SymbolManager.cpp           \
-                                TextDiagnostics.cpp         \
-                                WorkList.cpp)
-
-clangStaticAnalyzerFrontend_SRC = $(addprefix Frontend/,     \
-                                    AnalysisConsumer.cpp     \
-                                    AnalyzerHelpFlags.cpp    \
-                                    CheckerRegistry.cpp      \
-                                    CreateCheckerManager.cpp \
-                                    FrontendActions.cpp      \
-                                    ModelConsumer.cpp        \
-                                    ModelInjector.cpp)
-
-ALL_SOURCES = $(clangStaticAnalyzerCheckers_SRC) \
-              $(clangStaticAnalyzerCore_SRC)     \
-              $(clangStaticAnalyzerFrontend_SRC)
-
-clangStaticAnalyzerCheckers_OBJ = $(call cpp_to_obj, $(clangStaticAnalyzerCheckers_SRC))
-clangStaticAnalyzerCore_OBJ     = $(call cpp_to_obj, $(clangStaticAnalyzerCore_SRC))
-clangStaticAnalyzerFrontend_OBJ = $(call cpp_to_obj, $(clangStaticAnalyzerFrontend_SRC))
+StaticAnalyzerCheckers_SRC = $(addprefix Checkers/,                               \
+                               AnalysisOrderChecker.cpp                           \
+                               AnalyzerStatsChecker.cpp                           \
+                               ArrayBoundChecker.cpp                              \
+                               ArrayBoundCheckerV2.cpp                            \
+                               BasicObjCFoundationChecks.cpp                      \
+                               BlockInCriticalSectionChecker.cpp                  \
+                               BoolAssignmentChecker.cpp                          \
+                               BuiltinFunctionChecker.cpp                         \
+                               CStringChecker.cpp                                 \
+                               CStringSyntaxChecker.cpp                           \
+                               CallAndMessageChecker.cpp                          \
+                               CastSizeChecker.cpp                                \
+                               CastToStructChecker.cpp                            \
+                               CastValueChecker.cpp                               \
+                               CheckObjCDealloc.cpp                               \
+                               CheckObjCInstMethSignature.cpp                     \
+                               CheckPlacementNew.cpp                              \
+                               CheckSecuritySyntaxOnly.cpp                        \
+                               CheckSizeofPointer.cpp                             \
+                               CheckerDocumentation.cpp                           \
+                               ChrootChecker.cpp                                  \
+                               CloneChecker.cpp                                   \
+                               ContainerModeling.cpp                              \
+                               ConversionChecker.cpp                              \
+                               CXXSelfAssignmentChecker.cpp                       \
+                               DeadStoresChecker.cpp                              \
+                               DebugCheckers.cpp                                  \
+                               DebugContainerModeling.cpp                         \
+                               DebugIteratorModeling.cpp                          \
+                               DeleteWithNonVirtualDtorChecker.cpp                \
+                               DereferenceChecker.cpp                             \
+                               DirectIvarAssignment.cpp                           \
+                               DivZeroChecker.cpp                                 \
+                               DynamicTypePropagation.cpp                         \
+                               DynamicTypeChecker.cpp                             \
+                               EnumCastOutOfRangeChecker.cpp                      \
+                               ExprInspectionChecker.cpp                          \
+                               FixedAddressChecker.cpp                            \
+                               FuchsiaHandleChecker.cpp                           \
+                               GCDAntipatternChecker.cpp                          \
+                               GenericTaintChecker.cpp                            \
+                               GTestChecker.cpp                                   \
+                               IdenticalExprChecker.cpp                           \
+                               InnerPointerChecker.cpp                            \
+                               InvalidatedIteratorChecker.cpp                     \
+                               Iterator.cpp                                       \
+                               IteratorModeling.cpp                               \
+                               IteratorRangeChecker.cpp                           \
+                               IvarInvalidationChecker.cpp                        \
+                               LLVMConventionsChecker.cpp                         \
+                               LocalizationChecker.cpp                            \
+                               MacOSKeychainAPIChecker.cpp                        \
+                               MacOSXAPIChecker.cpp                               \
+                               MallocChecker.cpp                                  \
+                               MallocOverflowSecurityChecker.cpp                  \
+                               MallocSizeofChecker.cpp                            \
+                               MismatchedIteratorChecker.cpp                      \
+                               MmapWriteExecChecker.cpp                           \
+                               MIGChecker.cpp                                     \
+                               MoveChecker.cpp                                    \
+                               NSAutoreleasePoolChecker.cpp                       \
+                               NSErrorChecker.cpp                                 \
+                               NoReturnFunctionChecker.cpp                        \
+                               NonNullParamChecker.cpp                            \
+                               NonnullGlobalConstantsChecker.cpp                  \
+                               NullabilityChecker.cpp                             \
+                               NumberObjectConversionChecker.cpp                  \
+                               ObjCAtSyncChecker.cpp                              \
+                               ObjCAutoreleaseWriteChecker.cpp                    \
+                               ObjCContainersASTChecker.cpp                       \
+                               ObjCContainersChecker.cpp                          \
+                               ObjCMissingSuperCallChecker.cpp                    \
+                               ObjCPropertyChecker.cpp                            \
+                               ObjCSelfInitChecker.cpp                            \
+                               ObjCSuperDeallocChecker.cpp                        \
+                               ObjCUnusedIVarsChecker.cpp                         \
+                               OSObjectCStyleCast.cpp                             \
+                               PaddingChecker.cpp                                 \
+                               PointerArithChecker.cpp                            \
+                               PointerIterationChecker.cpp                        \
+                               PointerSortingChecker.cpp                          \
+                               PointerSubChecker.cpp                              \
+                               PthreadLockChecker.cpp                             \
+                               ReturnPointerRangeChecker.cpp                      \
+                               ReturnUndefChecker.cpp                             \
+                               ReturnValueChecker.cpp                             \
+                               RunLoopAutoreleaseLeakChecker.cpp                  \
+                               SimpleStreamChecker.cpp                            \
+                               SmartPtrChecker.cpp                                \
+                               SmartPtrModeling.cpp                               \
+                               StackAddrEscapeChecker.cpp                         \
+                               StdLibraryFunctionsChecker.cpp                     \
+                               STLAlgorithmModeling.cpp                           \
+                               StreamChecker.cpp                                  \
+                               Taint.cpp                                          \
+                               TaintTesterChecker.cpp                             \
+                               TestAfterDivZeroChecker.cpp                        \
+                               TraversalChecker.cpp                               \
+                               TrustNonnullChecker.cpp                            \
+                               UndefBranchChecker.cpp                             \
+                               UndefCapturedBlockVarChecker.cpp                   \
+                               UndefResultChecker.cpp                             \
+                               UndefinedArraySubscriptChecker.cpp                 \
+                               UndefinedAssignmentChecker.cpp                     \
+                               UninitializedObject/UninitializedObjectChecker.cpp \
+                               UninitializedObject/UninitializedPointee.cpp       \
+                               UnixAPIChecker.cpp                                 \
+                               UnreachableCodeChecker.cpp                         \
+                               VforkChecker.cpp                                   \
+                               VLASizeChecker.cpp                                 \
+                               ValistChecker.cpp                                  \
+                               VirtualCallChecker.cpp)
+
+StaticAnalyzerCheckers_SRC += Checkers/cert/PutenvWithAutoChecker.cpp
+
+StaticAnalyzerCheckers_SRC += $(addprefix Checkers/MPI-Checker/, \
+                                MPIBugReporter.cpp               \
+                                MPIChecker.cpp                   \
+                                MPIFunctionClassifier.cpp)
+
+StaticAnalyzerCheckers_SRC += $(addprefix Checkers/RetainCountChecker/, \
+                                RetainCountChecker.cpp                  \
+                                RetainCountDiagnostics.cpp)
+
+StaticAnalyzerCheckers_SRC += $(addprefix Checkers/UninitializedObject/, \
+                                UninitializedObjectChecker.cpp           \
+                                UninitializedPointee.cpp)
+
+StaticAnalyzerCheckers_SRC += $(addprefix Checkers/WebKit/,        \
+                                NoUncountedMembersChecker.cpp      \
+                                ASTUtils.cpp                       \
+                                PtrTypesSemantics.cpp              \
+                                RefCntblBaseVirtualDtorChecker.cpp \
+                                UncountedCallArgsChecker.cpp       \
+                                UncountedLambdaCapturesChecker.cpp)
+
+StaticAnalyzerCore_SRC = $(addprefix Core/,            \
+                           APSIntType.cpp              \
+                           AnalysisManager.cpp         \
+                           AnalyzerOptions.cpp         \
+                           BasicValueFactory.cpp       \
+                           BlockCounter.cpp            \
+                           BugReporter.cpp             \
+                           BugReporterVisitors.cpp     \
+                           CallEvent.cpp               \
+                           Checker.cpp                 \
+                           CheckerContext.cpp          \
+                           CheckerHelpers.cpp          \
+                           CheckerManager.cpp          \
+                           CheckerRegistryData.cpp     \
+                           CommonBugCategories.cpp     \
+                           ConstraintManager.cpp       \
+                           CoreEngine.cpp              \
+                           DynamicSize.cpp             \
+                           DynamicType.cpp             \
+                           Environment.cpp             \
+                           ExplodedGraph.cpp           \
+                           ExprEngine.cpp              \
+                           ExprEngineC.cpp             \
+                           ExprEngineCXX.cpp           \
+                           ExprEngineCallAndReturn.cpp \
+                           ExprEngineObjC.cpp          \
+                           FunctionSummary.cpp         \
+                           HTMLDiagnostics.cpp         \
+                           IssueHash.cpp               \
+                           LoopUnrolling.cpp           \
+                           LoopWidening.cpp            \
+                           MemRegion.cpp               \
+                           PlistDiagnostics.cpp        \
+                           ProgramState.cpp            \
+                           RangeConstraintManager.cpp  \
+                           RangedConstraintManager.cpp \
+                           RegionStore.cpp             \
+                           SarifDiagnostics.cpp        \
+                           SimpleConstraintManager.cpp \
+                           SimpleSValBuilder.cpp       \
+                           SMTConstraintManager.cpp    \
+                           Store.cpp                   \
+                           SValBuilder.cpp             \
+                           SVals.cpp                   \
+                           SymbolManager.cpp           \
+                           TextDiagnostics.cpp         \
+                           WorkList.cpp)
+
+StaticAnalyzerFrontend_SRC = $(addprefix Frontend/,     \
+                               AnalysisConsumer.cpp     \
+                               AnalyzerHelpFlags.cpp    \
+                               CheckerRegistry.cpp      \
+                               CreateCheckerManager.cpp \
+                               FrontendActions.cpp      \
+                               ModelConsumer.cpp        \
+                               ModelInjector.cpp)
+
+ALL_SOURCES = $(StaticAnalyzerCheckers_SRC) \
+              $(StaticAnalyzerCore_SRC)     \
+              $(StaticAnalyzerFrontend_SRC)
+
+StaticAnalyzerCheckers_OBJ = $(call cpp_to_obj, $(StaticAnalyzerCheckers_SRC))
+StaticAnalyzerCore_OBJ     = $(call cpp_to_obj, $(StaticAnalyzerCore_SRC))
+StaticAnalyzerFrontend_OBJ = $(call cpp_to_obj, $(StaticAnalyzerFrontend_SRC))
 
 all: $(GENERATED) $(TARGETS)
 
 ifeq ($(USE_MP_COMPILE),1)
-$(clangStaticAnalyzerCheckers_OBJ): $(clangStaticAnalyzerCheckers_SRC)
-	$(call MP_compile, $(clangStaticAnalyzerCheckers_SRC))
+$(StaticAnalyzerCheckers_OBJ): $(StaticAnalyzerCheckers_SRC)
+	$(call MP_compile, $(StaticAnalyzerCheckers_SRC))
 
-$(clangStaticAnalyzerCore_OBJ): $(clangStaticAnalyzerCore_SRC)
-	$(call MP_compile, $(clangStaticAnalyzerCore_SRC))
+$(StaticAnalyzerCore_OBJ): $(StaticAnalyzerCore_SRC)
+	$(call MP_compile, $(StaticAnalyzerCore_SRC))
 
-$(clangStaticAnalyzerFrontend_OBJ): $(clangStaticAnalyzerFrontend_SRC)
-	$(call MP_compile, $(clangStaticAnalyzerFrontend_SRC))
+$(StaticAnalyzerFrontend_OBJ): $(StaticAnalyzerFrontend_SRC)
+	$(call MP_compile, $(StaticAnalyzerFrontend_SRC))
 endif
 
-$(BUILD_DIR)/lib/clangStaticAnalyzerCheckers.lib: $(clangStaticAnalyzerCheckers_OBJ)
+$(BUILD_DIR)/lib/clangStaticAnalyzerCheckers.lib: $(StaticAnalyzerCheckers_OBJ)
 	 $(call create_lib, $@, $^)
 
-$(BUILD_DIR)/lib/clangStaticAnalyzerCore.lib: $(clangStaticAnalyzerCore_OBJ)
+$(BUILD_DIR)/lib/clangStaticAnalyzerCore.lib: $(StaticAnalyzerCore_OBJ)
 	 $(call create_lib, $@, $^)
 
-$(BUILD_DIR)/lib/clangStaticAnalyzerFrontend.lib: $(clangStaticAnalyzerFrontend_OBJ)
+$(BUILD_DIR)/lib/clangStaticAnalyzerFrontend.lib: $(StaticAnalyzerFrontend_OBJ)
 	 $(call create_lib, $@, $^)
 
 -include .depend.Windows
diff --git a/clang/lib/Tooling/Makefile.Windows b/clang/lib/Tooling/Makefile.Windows
index f5c7037..ee0a426 100644
--- a/clang/lib/Tooling/Makefile.Windows
+++ b/clang/lib/Tooling/Makefile.Windows
@@ -2,6 +2,7 @@
 # GNU Makefile for 'clang/lib/Tooling'.
 #
 TOP_DIR = ../../..
+
 TARGETS = $(BUILD_DIR)/lib/clangTooling.lib           \
           $(BUILD_DIR)/lib/clangToolingASTDiff.lib    \
           $(BUILD_DIR)/lib/clangToolingCore.lib       \
@@ -10,7 +11,14 @@ TARGETS = $(BUILD_DIR)/lib/clangTooling.lib           \
           $(BUILD_DIR)/lib/clangToolingSyntax.lib     \
           $(BUILD_DIR)/lib/clangDependencyScanning.lib
 
-VPATH = ASTDiff Core DependencyScanning Inclusions Refactoring Refactoring/Rename Syntax
+VPATH = ASTDiff             \
+        Core                \
+        DependencyScanning  \
+        Inclusions          \
+        Refactoring         \
+        Refactoring/Extract \
+        Refactoring/Rename  \
+        Syntax
 
 include $(TOP_DIR)/Common.Windows
 
@@ -20,120 +28,120 @@ include $(TOP_DIR)/Common.Windows
 INC_FILES = $(CLANG_INCLUDE_DIR)/Basic/DiagnosticCommonKinds.inc \
             $(CLANG_INCLUDE_DIR)/Basic/DiagnosticLexKinds.inc
 
-clangTooling_SRC = AllTUsExecution.cpp                        \
-                   ArgumentsAdjusters.cpp                     \
-                   CommonOptionsParser.cpp                    \
-                   CompilationDatabase.cpp                    \
-                   Execution.cpp                              \
-                   ExpandResponseFilesCompilationDatabase.cpp \
-                   FileMatchTrie.cpp                          \
-                   FixIt.cpp                                  \
-                   GuessTargetAndModeCompilationDatabase.cpp  \
-                   InterpolatingCompilationDatabase.cpp       \
-                   JSONCompilationDatabase.cpp                \
-                   Refactoring.cpp                            \
-                   RefactoringCallbacks.cpp                   \
-                   StandaloneExecution.cpp                    \
-                   Tooling.cpp
-
-clangToolingCore_SRC = $(addprefix Core/, \
-                         Diagnostic.cpp   \
-                         Lookup.cpp       \
-                         Replacement.cpp)
-
-clangToolingInclusions_SRC = $(addprefix Inclusions/, \
-                               HeaderIncludes.cpp     \
-                               IncludeStyle.cpp)
-
-clangToolingRefactor_SRC = $(addprefix Refactoring/,      \
-                             ASTSelection.cpp             \
-                             ASTSelectionRequirements.cpp \
-                             AtomicChange.cpp             \
-                             RefactoringActions.cpp)
-
-clangToolingRefactor_SRC += $(addprefix Refactoring/Rename/, \
-                              RenamingAction.cpp             \
-                              SymbolOccurrences.cpp          \
-                              USRFinder.cpp                  \
-                              USRFindingAction.cpp           \
-                              USRLocFinder.cpp)
-
-clangToolingRefactor_SRC += $(addprefix Refactoring/Extract/, \
-                              Extract.cpp                     \
-                              SourceExtraction.cpp)
-
-clangToolingSyntax_SRC  = $(addprefix Syntax/, \
-                            BuildTree.cpp      \
-                            Nodes.cpp          \
-                            Tokens.cpp         \
-                            Tree.cpp)
-
-clangToolingASTDiff_SRC = ASTDiff/AstDiff.cpp
-
-clangDependencyScanning_SRC = $(addprefix DependencyScanning/,   \
-                                DependencyScanningFilesystem.cpp \
-                                DependencyScanningService.cpp    \
-                                DependencyScanningWorker.cpp     \
-                                DependencyScanningTool.cpp       \
-                                ModuleDepCollector.cpp)
-
-ALL_SOURCES = $(clangTooling_SRC)           \
-              $(clangToolingASTDiff_SRC)    \
-              $(clangToolingCore_SRC)       \
-              $(clangToolingInclusions_SRC) \
-              $(clangToolingRefactor_SRC)   \
-              $(clangToolingSyntax_SRC)     \
-              $(clangDependencyScanning_SRC)
-
-clangTooling_OBJ            = $(call cpp_to_obj, $(clangTooling_SRC))
-clangToolingASTDiff_OBJ     = $(call cpp_to_obj, $(clangToolingASTDiff_SRC))
-clangToolingCore_OBJ        = $(call cpp_to_obj, $(clangToolingCore_SRC))
-clangToolingInclusions_OBJ  = $(call cpp_to_obj, $(clangToolingInclusions_SRC))
-clangToolingRefactor_OBJ    = $(call cpp_to_obj, $(clangToolingRefactor_SRC))
-clangToolingSyntax_OBJ      = $(call cpp_to_obj, $(clangToolingSyntax_SRC))
-clangDependencyScanning_OBJ = $(call cpp_to_obj, $(clangDependencyScanning_SRC))
-
-all: $(GENERATED) $(INC_FILES) $(TARGETS)
+Tooling_SRC = AllTUsExecution.cpp                        \
+              ArgumentsAdjusters.cpp                     \
+              CommonOptionsParser.cpp                    \
+              CompilationDatabase.cpp                    \
+              Execution.cpp                              \
+              ExpandResponseFilesCompilationDatabase.cpp \
+              FileMatchTrie.cpp                          \
+              FixIt.cpp                                  \
+              GuessTargetAndModeCompilationDatabase.cpp  \
+              InterpolatingCompilationDatabase.cpp       \
+              JSONCompilationDatabase.cpp                \
+              Refactoring.cpp                            \
+              RefactoringCallbacks.cpp                   \
+              StandaloneExecution.cpp                    \
+              Tooling.cpp
+
+ToolingCore_SRC = $(addprefix Core/, \
+                    Diagnostic.cpp   \
+                    Lookup.cpp       \
+                    Replacement.cpp)
+
+ToolingInclusions_SRC = $(addprefix Inclusions/, \
+                          HeaderIncludes.cpp     \
+                          IncludeStyle.cpp)
+
+ToolingRefactor_SRC = $(addprefix Refactoring/,      \
+                        ASTSelection.cpp             \
+                        ASTSelectionRequirements.cpp \
+                        AtomicChange.cpp             \
+                        RefactoringActions.cpp)
+
+ToolingRefactor_SRC += $(addprefix Refactoring/Rename/, \
+                         RenamingAction.cpp             \
+                         SymbolOccurrences.cpp          \
+                         USRFinder.cpp                  \
+                         USRFindingAction.cpp           \
+                         USRLocFinder.cpp)
+
+ToolingRefactor_SRC += $(addprefix Refactoring/Extract/, \
+                         Extract.cpp                     \
+                         SourceExtraction.cpp)
+
+ToolingSyntax_SRC  = $(addprefix Syntax/, \
+                       BuildTree.cpp      \
+                       Nodes.cpp          \
+                       Tokens.cpp         \
+                       Tree.cpp)
+
+ToolingASTDiff_SRC = ASTDiff/AstDiff.cpp
+
+DependencyScanning_SRC = $(addprefix DependencyScanning/,   \
+                           DependencyScanningFilesystem.cpp \
+                           DependencyScanningService.cpp    \
+                           DependencyScanningWorker.cpp     \
+                           DependencyScanningTool.cpp       \
+                           ModuleDepCollector.cpp)
+
+ALL_SOURCES = $(Tooling_SRC)           \
+              $(ToolingASTDiff_SRC)    \
+              $(ToolingCore_SRC)       \
+              $(ToolingInclusions_SRC) \
+              $(ToolingRefactor_SRC)   \
+              $(ToolingSyntax_SRC)     \
+              $(DependencyScanning_SRC)
+
+Tooling_OBJ            = $(call cpp_to_obj, $(Tooling_SRC))
+ToolingASTDiff_OBJ     = $(call cpp_to_obj, $(ToolingASTDiff_SRC))
+ToolingCore_OBJ        = $(call cpp_to_obj, $(ToolingCore_SRC))
+ToolingInclusions_OBJ  = $(call cpp_to_obj, $(ToolingInclusions_SRC))
+ToolingRefactor_OBJ    = $(call cpp_to_obj, $(ToolingRefactor_SRC))
+ToolingSyntax_OBJ      = $(call cpp_to_obj, $(ToolingSyntax_SRC))
+DependencyScanning_OBJ = $(call cpp_to_obj, $(DependencyScanning_SRC))
+
+all: $(GENERATED) inc_files $(TARGETS)
 
 ifeq ($(USE_MP_COMPILE),1)
-$(clangTooling_OBJ): $(clangTooling_SRC)
-	$(call MP_compile, $(clangTooling_SRC))
+$(Tooling_OBJ): $(Tooling_SRC)
+	$(call MP_compile, $(Tooling_SRC))
 
-$(clangToolingCore_OBJ): $(clangToolingCore_SRC)
-	$(call MP_compile, $(clangToolingCore_SRC))
+$(ToolingCore_OBJ): $(ToolingCore_SRC)
+	$(call MP_compile, $(ToolingCore_SRC))
 
-$(clangToolingRefactor_OBJ): $(clangToolingRefactor_SRC)
-	$(call MP_compile, $(clangToolingRefactor_SRC))
+$(ToolingRefactor_OBJ): $(ToolingRefactor_SRC)
+	$(call MP_compile, $(ToolingRefactor_SRC))
 
-$(clangToolingSyntax_OBJ): $(clangToolingSyntax_SRC)
-	$(call MP_compile, $(clangToolingSyntax_SRC))
+$(ToolingSyntax_OBJ): $(ToolingSyntax_SRC)
+	$(call MP_compile, $(ToolingSyntax_SRC))
 
-$(clangDependencyScanning_OBJ): $(clangDependencyScanning_SRC)
-	$(call MP_compile, $(clangDependencyScanning_SRC))
+$(DependencyScanning_OBJ): $(DependencyScanning_SRC)
+	$(call MP_compile, $(DependencyScanning_SRC))
 endif
 
-$(BUILD_DIR)/lib/clangTooling.lib: $(clangTooling_OBJ)
+$(BUILD_DIR)/lib/clangTooling.lib: $(Tooling_OBJ)
 	 $(call create_lib, $@, $^)
 
-$(BUILD_DIR)/lib/clangToolingASTDiff.lib: $(clangToolingASTDiff_OBJ)
+$(BUILD_DIR)/lib/clangToolingASTDiff.lib: $(ToolingASTDiff_OBJ)
 	 $(call create_lib, $@, $^)
 
-$(BUILD_DIR)/lib/clangToolingCore.lib: $(clangToolingCore_OBJ)
+$(BUILD_DIR)/lib/clangToolingCore.lib: $(ToolingCore_OBJ)
 	 $(call create_lib, $@, $^)
 
-$(BUILD_DIR)/lib/clangToolingInclusions.lib: $(clangToolingInclusions_OBJ)
+$(BUILD_DIR)/lib/clangToolingInclusions.lib: $(ToolingInclusions_OBJ)
 	 $(call create_lib, $@, $^)
 
-$(BUILD_DIR)/lib/clangToolingRefactor.lib: $(clangToolingRefactor_OBJ)
+$(BUILD_DIR)/lib/clangToolingRefactor.lib: $(ToolingRefactor_OBJ)
 	 $(call create_lib, $@, $^)
 
-$(BUILD_DIR)/lib/clangToolingSyntax.lib: $(clangToolingSyntax_OBJ)
+$(BUILD_DIR)/lib/clangToolingSyntax.lib: $(ToolingSyntax_OBJ)
 	 $(call create_lib, $@, $^)
 
-$(BUILD_DIR)/lib/clangDependencyScanning.lib: $(clangDependencyScanning_OBJ)
+$(BUILD_DIR)/lib/clangDependencyScanning.lib: $(DependencyScanning_OBJ)
 	 $(call create_lib, $@, $^)
 
-$(INC_FILES):
+inc_files::
 	$(call do_make, $(CLANG_INCLUDE_DIR), all)
 
 -include .depend.Windows
diff --git a/clang/tools/c-index-test/Makefile.Windows b/clang/tools/c-index-test/Makefile.Windows
index e051d29..cd52f71 100644
--- a/clang/tools/c-index-test/Makefile.Windows
+++ b/clang/tools/c-index-test/Makefile.Windows
@@ -38,7 +38,6 @@ LIBS += $(addprefix $(BUILD_DIR)/lib/,  \
           LLVMBitstreamReader.lib       \
           LLVMBitReader.lib             \
           LLVMBitWriter.lib             \
-          LLVMCodeGen.lib               \
           LLVMCore.lib                  \
           LLVMCoroutines.lib            \
           LLVMCoverage.lib              \
@@ -76,7 +75,18 @@ ifeq ($(USE_ZLIB),1)
 endif
 
 ifeq ($(USE_XML2),1)
-  CFLAGS  += -I$(XML2_ROOT)/include
+  CFLAGS += -I$(XML2_ROOT)/include
+
+  #
+  # In case 'libxml2' was configured with 'LIBXML_ICONV_ENABLED'
+  #
+  CFLAGS += -I$(ICONV_ROOT)/include
+
+  #
+  # Use the static 'xml2.lib'
+  #
+  CFLAGS += -DLIBXML_STATIC
+
   EX_LIBS += $(XML2_LIB) $(LZMA_LIB) $(ICONV_LIB) ws2_32.lib
 endif
 
diff --git a/clang/tools/driver/Makefile.Windows b/clang/tools/driver/Makefile.Windows
index a7681bc..c91ca68 100644
--- a/clang/tools/driver/Makefile.Windows
+++ b/clang/tools/driver/Makefile.Windows
@@ -44,7 +44,6 @@ LIBS = $(addprefix $(BUILD_DIR)/lib/,    \
          clangStaticAnalyzerCheckers.lib \
          clangStaticAnalyzerCore.lib     \
          clangStaticAnalyzerFrontend.lib \
-         clangTooling.lib                \
          clangToolingCore.lib)
 
 LIBS += $(addprefix $(BUILD_DIR)/lib/,  \
@@ -158,7 +157,7 @@ LIBS += $(addprefix $(BUILD_DIR)/lib/,  \
 EX_LIBS = advapi32.lib ole32.lib shell32.lib version.lib
 
 #
-# Why is this a good idea?
+# Because of the above '-delayload:xx.dll' statements.
 #
 EX_LIBS += delayimp.lib
 
@@ -166,18 +165,25 @@ ifeq ($(USE_ZLIB),1)
   EX_LIBS += $(ZLIB_LIB)
 endif
 
+long_time = $(call green_msg, This will take a $(BRIGHT_RED)long time...)
+
 $(BUILD_DIR)/bin/clang.exe: $(OBJECTS) $(LIBS) $(OBJ_DIR)/clang.res
+	$(long_time)
 	$(call link_EXE, $@, $^ $(EX_LIBS))
 
 $(BUILD_DIR)/bin/clang-cl.exe: $(OBJECTS) $(LIBS) $(OBJ_DIR)/clang-cl.res
+	$(long_time)
 	$(call link_EXE, $@, $^ $(EX_LIBS))
 
 $(BUILD_DIR)/bin/clang-cpp.exe: $(OBJECTS) $(LIBS) $(OBJ_DIR)/clang-cpp.res
+	$(long_time)
 	$(call link_EXE, $@, $^ $(EX_LIBS))
 
 $(BUILD_DIR)/bin/clang++.exe: $(OBJECTS) $(LIBS) $(OBJ_DIR)/clang++.res
+	$(long_time)
 	$(call link_EXE, $@, $^ $(EX_LIBS))
 
+
 $(OBJ_DIR)/clang.rc: $(MDEPEND)
 	$(call make_rc, $@, clang.exe, VFT_APP, The clang compiler.)
 
diff --git a/clang/tools/libclang/Makefile.Windows b/clang/tools/libclang/Makefile.Windows
index 9ed1e50..437f5a9 100644
--- a/clang/tools/libclang/Makefile.Windows
+++ b/clang/tools/libclang/Makefile.Windows
@@ -194,7 +194,7 @@ endif
 $(BUILD_DIR)/lib/libclang.lib: $(BUILD_DIR)/bin/libclang.dll
 
 $(BUILD_DIR)/bin/libclang.dll: $(OBJECTS) $(OBJ_DIR)/libclang.res $(LIBS)
-	$(call green_msg,This will take a $(BRIGHT_RED)long time.)
+	$(call green_msg, This will take a $(BRIGHT_RED)long time.)
 	$(call link_DLL, $@, $(BUILD_DIR)/lib/libclang.lib, $^ $(EX_LIBS))
 
 $(OBJ_DIR)/libclang.rc: $(MDEPEND)
diff --git a/llvm/lib/Analysis/Makefile.Windows b/llvm/lib/Analysis/Makefile.Windows
index c06552b..2ed7b07 100644
--- a/llvm/lib/Analysis/Makefile.Windows
+++ b/llvm/lib/Analysis/Makefile.Windows
@@ -32,6 +32,7 @@ LIB_SRC = AliasAnalysis.cpp                 \
           AliasAnalysisSummary.cpp          \
           AliasSetTracker.cpp               \
           Analysis.cpp                      \
+          AssumeBundleQueries.cpp           \
           AssumptionCache.cpp               \
           BasicAliasAnalysis.cpp            \
           BlockFrequencyInfo.cpp            \
@@ -60,11 +61,15 @@ LIB_SRC = AliasAnalysis.cpp                 \
           DomTreeUpdater.cpp                \
           DominanceFrontier.cpp             \
           EHPersonalities.cpp               \
+          FunctionPropertiesAnalysis.cpp    \
           GlobalsModRef.cpp                 \
           GuardUtils.cpp                    \
+          HeatUtils.cpp                     \
+          InlineSizeEstimatorAnalysis.cpp   \
           IVDescriptors.cpp                 \
           IVUsers.cpp                       \
           IndirectCallPromotionAnalysis.cpp \
+          InlineAdvisor.cpp                 \
           InlineCost.cpp                    \
           InstCount.cpp                     \
           InstructionPrecedenceTracking.cpp \
@@ -99,7 +104,6 @@ LIB_SRC = AliasAnalysis.cpp                 \
           ObjCARCAnalysisUtils.cpp          \
           ObjCARCInstKind.cpp               \
           OptimizationRemarkEmitter.cpp     \
-          OrderedInstructions.cpp           \
           PHITransAddr.cpp                  \
           PhiValues.cpp                     \
           PostDominators.cpp                \
@@ -110,8 +114,9 @@ LIB_SRC = AliasAnalysis.cpp                 \
           RegionPrinter.cpp                 \
           ScalarEvolution.cpp               \
           ScalarEvolutionAliasAnalysis.cpp  \
-          ScalarEvolutionExpander.cpp       \
+          ScalarEvolutionDivision.cpp       \
           ScalarEvolutionNormalization.cpp  \
+          StackLifetime.cpp                 \
           StackSafetyAnalysis.cpp           \
           SyncDependenceAnalysis.cpp        \
           SyntheticCountsUtils.cpp          \
diff --git a/llvm/lib/CodeGen/Makefile.Windows b/llvm/lib/CodeGen/Makefile.Windows
index 69bb100..a218a9d 100644
--- a/llvm/lib/CodeGen/Makefile.Windows
+++ b/llvm/lib/CodeGen/Makefile.Windows
@@ -14,12 +14,12 @@ CodeGen_SRC = AggressiveAntiDepBreaker.cpp         \
               AllocationOrder.cpp                  \
               Analysis.cpp                         \
               AtomicExpandPass.cpp                 \
+              BasicBlockSections.cpp               \
               BasicTargetTransformInfo.cpp         \
               BranchFolding.cpp                    \
               BranchRelaxation.cpp                 \
               BreakFalseDeps.cpp                   \
               BuiltinGCs.cpp                       \
-              BBSectionsPrepare.cpp                \
               CalcSpillWeights.cpp                 \
               CallingConvLower.cpp                 \
               CFGuardLongjmp.cpp                   \
@@ -41,6 +41,7 @@ CodeGen_SRC = AggressiveAntiDepBreaker.cpp         \
               FaultMaps.cpp                        \
               FEntryInserter.cpp                   \
               FinalizeISel.cpp                     \
+              FixupStatepointCallerSaved.cpp       \
               FuncletLayout.cpp                    \
               GCMetadata.cpp                       \
               GCMetadataPrinter.cpp                \
@@ -61,8 +62,9 @@ CodeGen_SRC = AggressiveAntiDepBreaker.cpp         \
               LexicalScopes.cpp                    \
               LiveDebugValues.cpp                  \
               LiveDebugVariables.cpp               \
-              LiveIntervals.cpp                    \
               LiveInterval.cpp                     \
+              LiveIntervals.cpp                    \
+              LiveIntervalCalc.cpp                 \
               LiveIntervalUnion.cpp                \
               LivePhysRegs.cpp                     \
               LiveRangeCalc.cpp                    \
@@ -84,6 +86,7 @@ CodeGen_SRC = AggressiveAntiDepBreaker.cpp         \
               MachineCombiner.cpp                  \
               MachineCopyPropagation.cpp           \
               MachineCSE.cpp                       \
+              MachineDebugify.cpp                  \
               MachineDominanceFrontier.cpp         \
               MachineDominators.cpp                \
               MachineFrameInfo.cpp                 \
@@ -108,6 +111,7 @@ CodeGen_SRC = AggressiveAntiDepBreaker.cpp         \
               MachineSink.cpp                      \
               MachineSizeOpts.cpp                  \
               MachineSSAUpdater.cpp                \
+              MachineStripDebug.cpp                \
               MachineTraceMetrics.cpp              \
               MachineVerifier.cpp                  \
               ModuloSchedule.cpp                   \
@@ -150,7 +154,6 @@ CodeGen_SRC = AggressiveAntiDepBreaker.cpp         \
               RegUsageInfoPropagate.cpp            \
               ResetMachineFunctionPass.cpp         \
               SafeStack.cpp                        \
-              SafeStackColoring.cpp                \
               SafeStackLayout.cpp                  \
               ScalarizeMaskedMemIntrin.cpp         \
               ScheduleDAG.cpp                      \
@@ -257,28 +260,30 @@ MIRParser_SRC = $(addprefix MIRParser/, \
 
 VPATH += GlobalISel
 
-GlobalISel_SRC = $(addprefix GlobalISel/,  \
-                   CSEInfo.cpp             \
-                   GISelKnownBits.cpp      \
-                   CSEMIRBuilder.cpp       \
-                   CallLowering.cpp        \
-                   GlobalISel.cpp          \
-                   Combiner.cpp            \
-                   CombinerHelper.cpp      \
-                   GISelChangeObserver.cpp \
-                   IRTranslator.cpp        \
-                   InstructionSelect.cpp   \
-                   InstructionSelector.cpp \
-                   LegalityPredicates.cpp  \
-                   LegalizeMutations.cpp   \
-                   Legalizer.cpp           \
-                   LegalizerHelper.cpp     \
-                   LegalizerInfo.cpp       \
-                   Localizer.cpp           \
-                   MachineIRBuilder.cpp    \
-                   RegBankSelect.cpp       \
-                   RegisterBank.cpp        \
-                   RegisterBankInfo.cpp    \
+GlobalISel_SRC = $(addprefix GlobalISel/,   \
+                   CSEInfo.cpp              \
+                   GISelKnownBits.cpp       \
+                   CSEMIRBuilder.cpp        \
+                   CallLowering.cpp         \
+                   GlobalISel.cpp           \
+                   Combiner.cpp             \
+                   CombinerHelper.cpp       \
+                   GISelChangeObserver.cpp  \
+                   IRTranslator.cpp         \
+                   InlineAsmLowering.cpp    \
+                   InstructionSelect.cpp    \
+                   InstructionSelector.cpp  \
+                   LegalityPredicates.cpp   \
+                   LegalizeMutations.cpp    \
+                   Legalizer.cpp            \
+                   LegalizerHelper.cpp      \
+                   LegalizerInfo.cpp        \
+                   Localizer.cpp            \
+                   LostDebugLocObserver.cpp \
+                   MachineIRBuilder.cpp     \
+                   RegBankSelect.cpp        \
+                   RegisterBank.cpp         \
+                   RegisterBankInfo.cpp     \
                    Utils.cpp)
 
 ALL_SOURCES = $(AsmPrinter_SRC) $(CodeGen_SRC) $(GlobalISel_SRC) $(MIRParser_SRC) $(SelectionDAG_SRC)
diff --git a/llvm/lib/DebugInfo/Makefile.Windows b/llvm/lib/DebugInfo/Makefile.Windows
index 855b515..840eee1 100644
--- a/llvm/lib/DebugInfo/Makefile.Windows
+++ b/llvm/lib/DebugInfo/Makefile.Windows
@@ -9,6 +9,8 @@ TARGETS = $(BUILD_DIR)/lib/LLVMDebugInfoCodeView.lib \
           $(BUILD_DIR)/lib/LLVMDebugInfoPDB.lib      \
           $(BUILD_DIR)/lib/LLVMSymbolize.lib
 
+VPATH = DWARF GSYM MSF CodeView PDB PDB/DIA PDB/Native Symbolize
+
 #
 # Since there are 2 of 'EnumTables.cpp'.
 #
@@ -16,8 +18,6 @@ GENERATED = CodeView/EnumTables_CodeView.cpp
 
 include $(TOP_DIR)/Common.Windows
 
-VPATH = DWARF
-
 DebugInfoDwarf_SRC = $(addprefix DWARF/,                \
                        DWARFAbbreviationDeclaration.cpp \
                        DWARFAddressRange.cpp            \
@@ -42,32 +42,30 @@ DebugInfoDwarf_SRC = $(addprefix DWARF/,                \
                        DWARFFormValue.cpp               \
                        DWARFGdbIndex.cpp                \
                        DWARFListTable.cpp               \
+                       DWARFLocationExpression.cpp      \
                        DWARFTypeUnit.cpp                \
                        DWARFUnitIndex.cpp               \
                        DWARFUnit.cpp                    \
                        DWARFVerifier.cpp)
 
-VPATH += GSYM
-
-DebugInfoGSYM_SRC = $(addprefix GSYM/,     \
-                      DwarfTransformer.cpp \
-                      FileWriter.cpp       \
-                      FunctionInfo.cpp     \
-                      InlineInfo.cpp       \
-                      GsymCreator.cpp      \
-                      GsymReader.cpp       \
-                      Header.cpp           \
-                      LineTable.cpp        \
+DebugInfoGSYM_SRC = $(addprefix GSYM/,          \
+                      DwarfTransformer.cpp      \
+                      FileWriter.cpp            \
+                      FunctionInfo.cpp          \
+                      InlineInfo.cpp            \
+                      GsymCreator.cpp           \
+                      GsymReader.cpp            \
+                      Header.cpp                \
+                      LineTable.cpp             \
+                      LookupResult.cpp          \
+                      ObjectFileTransformer.cpp \
                       Range.cpp)
 
-VPATH += MSF
-
 DebugInfoMSF_SRC = $(addprefix MSF/,       \
                      MappedBlockStream.cpp \
                      MSFBuilder.cpp        \
                      MSFCommon.cpp         \
                      MSFError.cpp)
-VPATH += CodeView
 
 DebugInfoCodeView_SRC = $(addprefix CodeView/,            \
                           AppendingTypeTableBuilder.cpp   \
@@ -98,9 +96,9 @@ DebugInfoCodeView_SRC = $(addprefix CodeView/,            \
                           RecordSerialization.cpp         \
                           SimpleTypeSerializer.cpp        \
                           StringsAndChecksums.cpp         \
-                          SymbolRecordMapping.cpp         \
                           SymbolDumper.cpp                \
                           SymbolRecordHelpers.cpp         \
+                          SymbolRecordMapping.cpp         \
                           SymbolSerializer.cpp            \
                           TypeDumpVisitor.cpp             \
                           TypeIndex.cpp                   \
@@ -110,52 +108,49 @@ DebugInfoCodeView_SRC = $(addprefix CodeView/,            \
                           TypeRecordMapping.cpp           \
                           TypeStreamMerger.cpp            \
                           TypeTableCollection.cpp)
-VPATH += PDB
 
-DebugInfoPDB_SRC = $(addprefix PDB/,                 \
-                     GenericError.cpp                \
-                     IPDBSourceFile.cpp              \
-                     PDB.cpp                         \
-                     PDBContext.cpp                  \
-                     PDBExtras.cpp                   \
-                     PDBInterfaceAnchors.cpp         \
-                     PDBSymbol.cpp                   \
-                     PDBSymbolAnnotation.cpp         \
-                     PDBSymbolBlock.cpp              \
-                     PDBSymbolCompiland.cpp          \
-                     PDBSymbolCompilandDetails.cpp   \
-                     PDBSymbolCompilandEnv.cpp       \
-                     PDBSymbolCustom.cpp             \
-                     PDBSymbolData.cpp               \
-                     PDBSymbolExe.cpp                \
-                     PDBSymbolFunc.cpp               \
-                     PDBSymbolFuncDebugEnd.cpp       \
-                     PDBSymbolFuncDebugStart.cpp     \
-                     PDBSymbolLabel.cpp              \
-                     PDBSymbolPublicSymbol.cpp       \
-                     PDBSymbolThunk.cpp              \
-                     PDBSymbolTypeArray.cpp          \
-                     PDBSymbolTypeBaseClass.cpp      \
-                     PDBSymbolTypeBuiltin.cpp        \
-                     PDBSymbolTypeCustom.cpp         \
-                     PDBSymbolTypeDimension.cpp      \
-                     PDBSymbolTypeEnum.cpp           \
-                     PDBSymbolTypeFriend.cpp         \
-                     PDBSymbolTypeFunctionArg.cpp    \
-                     PDBSymbolTypeFunctionSig.cpp    \
-                     PDBSymbolTypeManaged.cpp        \
-                     PDBSymbolTypePointer.cpp        \
-                     PDBSymbolTypeTypedef.cpp        \
-                     PDBSymbolTypeUDT.cpp            \
-                     PDBSymbolTypeVTable.cpp         \
-                     PDBSymbolTypeVTableShape.cpp    \
-                     PDBSymbolUnknown.cpp            \
-                     PDBSymbolUsingNamespace.cpp     \
-                     PDBSymDumper.cpp                \
+DebugInfoPDB_SRC = $(addprefix PDB/,               \
+                     GenericError.cpp              \
+                     IPDBSourceFile.cpp            \
+                     PDB.cpp                       \
+                     PDBContext.cpp                \
+                     PDBExtras.cpp                 \
+                     PDBInterfaceAnchors.cpp       \
+                     PDBSymbol.cpp                 \
+                     PDBSymbolAnnotation.cpp       \
+                     PDBSymbolBlock.cpp            \
+                     PDBSymbolCompiland.cpp        \
+                     PDBSymbolCompilandDetails.cpp \
+                     PDBSymbolCompilandEnv.cpp     \
+                     PDBSymbolCustom.cpp           \
+                     PDBSymbolData.cpp             \
+                     PDBSymbolExe.cpp              \
+                     PDBSymbolFunc.cpp             \
+                     PDBSymbolFuncDebugEnd.cpp     \
+                     PDBSymbolFuncDebugStart.cpp   \
+                     PDBSymbolLabel.cpp            \
+                     PDBSymbolPublicSymbol.cpp     \
+                     PDBSymbolThunk.cpp            \
+                     PDBSymbolTypeArray.cpp        \
+                     PDBSymbolTypeBaseClass.cpp    \
+                     PDBSymbolTypeBuiltin.cpp      \
+                     PDBSymbolTypeCustom.cpp       \
+                     PDBSymbolTypeDimension.cpp    \
+                     PDBSymbolTypeEnum.cpp         \
+                     PDBSymbolTypeFriend.cpp       \
+                     PDBSymbolTypeFunctionArg.cpp  \
+                     PDBSymbolTypeFunctionSig.cpp  \
+                     PDBSymbolTypeManaged.cpp      \
+                     PDBSymbolTypePointer.cpp      \
+                     PDBSymbolTypeTypedef.cpp      \
+                     PDBSymbolTypeUDT.cpp          \
+                     PDBSymbolTypeVTable.cpp       \
+                     PDBSymbolTypeVTableShape.cpp  \
+                     PDBSymbolUnknown.cpp          \
+                     PDBSymbolUsingNamespace.cpp   \
+                     PDBSymDumper.cpp              \
                      UDTLayout.cpp)
 
-VPATH += PDB/DIA
-
 DebugInfoPDB_SRC += $(addprefix PDB/DIA/,        \
                       DIADataStream.cpp          \
                       DIAEnumDebugStreams.cpp    \
@@ -176,8 +171,6 @@ DebugInfoPDB_SRC += $(addprefix PDB/DIA/,        \
                       DIASourceFile.cpp          \
                       DIATable.cpp)
 
-VPATH += PDB/Native
-
 DebugInfoPDB_SRC += $(addprefix PDB/Native/,         \
                       DbiModuleDescriptor.cpp        \
                       DbiModuleDescriptorBuilder.cpp \
@@ -195,10 +188,15 @@ DebugInfoPDB_SRC += $(addprefix PDB/Native/,         \
                       NativeCompilandSymbol.cpp      \
                       NativeEnumGlobals.cpp          \
                       NativeEnumInjectedSources.cpp  \
+                      NativeEnumLineNumbers.cpp      \
                       NativeEnumModules.cpp          \
                       NativeEnumTypes.cpp            \
                       NativeExeSymbol.cpp            \
+                      NativeFunctionSymbol.cpp       \
+                      NativeLineNumber.cpp           \
+                      NativePublicSymbol.cpp         \
                       NativeRawSymbol.cpp            \
+                      NativeSourceFile.cpp           \
                       NativeSymbolEnumerator.cpp     \
                       NativeTypeArray.cpp            \
                       NativeTypeBuiltin.cpp          \
@@ -223,8 +221,6 @@ DebugInfoPDB_SRC += $(addprefix PDB/Native/,         \
                       TpiStream.cpp                  \
                       TpiStreamBuilder.cpp)
 
-VPATH += Symbolize
-
 Symbolize_SRC = $(addprefix Symbolize/,      \
                   DIPrinter.cpp              \
                   SymbolizableObjectFile.cpp \
diff --git a/llvm/lib/ExecutionEngine/Makefile.Windows b/llvm/lib/ExecutionEngine/Makefile.Windows
index bb52313..08335f7 100644
--- a/llvm/lib/ExecutionEngine/Makefile.Windows
+++ b/llvm/lib/ExecutionEngine/Makefile.Windows
@@ -3,7 +3,8 @@
 #
 TOP_DIR = ../../..
 
-VPATH = Interpreter     \
+VPATH = IntelJITEvents  \
+        Interpreter     \
         JITLink         \
         MCJIT           \
         OProfileJIT Orc \
@@ -12,12 +13,14 @@ VPATH = Interpreter     \
         RuntimeDyld/Targets
 
 TARGETS = $(BUILD_DIR)/lib/LLVMExecutionEngine.lib \
-          $(BUILD_DIR)/lib/LLVMInterpreter.lib     \
-          $(BUILD_DIR)/lib/LLVMJITLink.lib         \
-          $(BUILD_DIR)/lib/LLVMMCJIT.lib           \
-          $(BUILD_DIR)/lib/LLVMOrcJIT.lib          \
-          $(BUILD_DIR)/lib/LLVMOrcError.lib        \
-          $(BUILD_DIR)/lib/LLVMRuntimeDyld.lib
+        # $(BUILD_DIR)/lib/LLVMIntelJITEvents.lib
+
+TARGETS += $(BUILD_DIR)/lib/LLVMInterpreter.lib     \
+           $(BUILD_DIR)/lib/LLVMJITLink.lib         \
+           $(BUILD_DIR)/lib/LLVMMCJIT.lib           \
+           $(BUILD_DIR)/lib/LLVMOrcJIT.lib          \
+           $(BUILD_DIR)/lib/LLVMOrcError.lib        \
+           $(BUILD_DIR)/lib/LLVMRuntimeDyld.lib
 
 #
 # Needs 'opagent.h' which is nowhere.
@@ -37,16 +40,21 @@ ExecutionEngine_SRC = ExecutionEngine.cpp         \
                       SectionMemoryManager.cpp    \
                       TargetSelect.cpp
 
+IntelJITEvents_CPP_SRC = IntelJITEvents/IntelJITEventListener.cpp
+IntelJITEvents_C_SRC   = IntelJITEvents/jitprofiling.c
+
 Interpreter_SRC = $(addprefix Interpreter/, \
                     Execution.cpp           \
                     ExternalFunctions.cpp   \
                     Interpreter.cpp)
 
 JITLink_SRC = $(addprefix JITLink/,      \
+                EHFrameSupport.cpp       \
+                ELF.cpp                  \
+                ELF_x86_64.cpp           \
                 JITLink.cpp              \
                 JITLinkGeneric.cpp       \
                 JITLinkMemoryManager.cpp \
-                EHFrameSupport.cpp       \
                 MachO.cpp                \
                 MachO_arm64.cpp          \
                 MachO_x86_64.cpp         \
@@ -58,32 +66,35 @@ OProfileJIT_SRC = $(addprefix OProfileJIT/,      \
                     OProfileJITEventListener.cpp \
                     OProfileWrapper.cpp)
 
-OrcJIT_SRC = $(addprefix Orc/,              \
-               CompileOnDemandLayer.cpp     \
-               CompileUtils.cpp             \
-               Core.cpp                     \
-               DebugUtils.cpp               \
-               ExecutionUtils.cpp           \
-               IndirectionUtils.cpp         \
-               IRCompileLayer.cpp           \
-               IRTransformLayer.cpp         \
-               JITTargetMachineBuilder.cpp  \
-               LazyReexports.cpp            \
-               Legacy.cpp                   \
-               Layer.cpp                    \
-               LLJIT.cpp                    \
-               MachOPlatform.cpp            \
-               Mangling.cpp                 \
-               NullResolver.cpp             \
-               ObjectLinkingLayer.cpp       \
-               ObjectTransformLayer.cpp     \
-               OrcABISupport.cpp            \
-               OrcCBindings.cpp             \
-               OrcV2CBindings.cpp           \
-               OrcMCJITReplacement.cpp      \
-               RTDyldObjectLinkingLayer.cpp \
-               ThreadSafeModule.cpp         \
-               Speculation.cpp              \
+OrcJIT_SRC = $(addprefix Orc/,                      \
+               CompileOnDemandLayer.cpp             \
+               CompileUtils.cpp                     \
+               Core.cpp                             \
+               DebugUtils.cpp                       \
+               ExecutionUtils.cpp                   \
+               IndirectionUtils.cpp                 \
+               IRCompileLayer.cpp                   \
+               IRTransformLayer.cpp                 \
+               JITTargetMachineBuilder.cpp          \
+               LazyReexports.cpp                    \
+               Legacy.cpp                           \
+               Layer.cpp                            \
+               LLJIT.cpp                            \
+               MachOPlatform.cpp                    \
+               Mangling.cpp                         \
+               NullResolver.cpp                     \
+               ObjectLinkingLayer.cpp               \
+               ObjectTransformLayer.cpp             \
+               OrcABISupport.cpp                    \
+               OrcCBindings.cpp                     \
+               OrcV2CBindings.cpp                   \
+               OrcMCJITReplacement.cpp              \
+               RTDyldObjectLinkingLayer.cpp         \
+               TargetProcessControl.cpp             \
+               ThreadSafeModule.cpp                 \
+               TPCDynamicLibrarySearchGenerator.cpp \
+               TPCIndirectionUtils.cpp              \
+               Speculation.cpp                      \
                SpeculateAnalyses.cpp)
 
 OrcError_SRC = $(addprefix OrcError/, \
@@ -110,6 +121,7 @@ ALL_SOURCES = $(ExecutionEngine_SRC) \
               $(RuntimeDyld_SRC)
 
 ExecutionEngine_OBJ = $(call cpp_to_obj, $(ExecutionEngine_SRC))
+IntelJITEvents_OBJ  = $(call cpp_to_obj, $(IntelJITEvents_CPP_SRC)) $(call c_to_obj, $(IntelJITEvents_C_SRC))
 Interpreter_OBJ     = $(call cpp_to_obj, $(Interpreter_SRC))
 JITLink_OBJ         = $(call cpp_to_obj, $(JITLink_SRC))
 MCJIT_OBJ           = $(call cpp_to_obj, $(MCJIT_SRC))
@@ -140,6 +152,9 @@ endif
 $(BUILD_DIR)/lib/LLVMExecutionEngine.lib: $(ExecutionEngine_OBJ)
 	 $(call create_lib, $@, $^)
 
+$(BUILD_DIR)/lib/LLVMIntelJITEvents.lib: $(IntelJITEvents_OBJ)
+	 $(call create_lib, $@, $^)
+
 $(BUILD_DIR)/lib/LLVMInterpreter.lib: $(Interpreter_OBJ)
 	 $(call create_lib, $@, $^)
 
diff --git a/llvm/lib/Frontend/Makefile.Windows b/llvm/lib/Frontend/Makefile.Windows
index fcf948e..9952079 100644
--- a/llvm/lib/Frontend/Makefile.Windows
+++ b/llvm/lib/Frontend/Makefile.Windows
@@ -3,14 +3,24 @@
 #
 TOP_DIR = ../../..
 TARGETS = $(BUILD_DIR)/lib/LLVMFrontendOpenMP.lib
-VPATH   = OpenMP
+VPATH   = OpenACC OpenMP
+
+GENERATED = OpenACC/ACC.cpp \
+            OpenMP/OMP.cpp
+
+GENERATED += $(addprefix ../../include/llvm/Frontend/, \
+               OpenACC/ACC.h.inc                       \
+               OpenMP/OMP.h.inc                        \
+               OpenMP/OMP.cpp.inc)
 
 include $(TOP_DIR)/Common.Windows
 
-LIB_SRC = $(addprefix OpenMP/, \
-            OMPConstants.cpp   \
-            OMPContext.cpp     \
-            OMPIRBuilder.cpp)
+LIB_SRC = OpenACC/ACC.cpp
+
+LIB_SRC += $(addprefix OpenMP/, \
+             OMP.cpp            \
+             OMPContext.cpp     \
+             OMPIRBuilder.cpp)
 
 ALL_SOURCES = $(LIB_SRC)
 
@@ -21,5 +31,20 @@ all: $(GENERATED) $(TARGETS)
 $(BUILD_DIR)/lib/LLVMFrontendOpenMP.lib: $(LIB_OBJ)
 	 $(call create_lib, $@, $^)
 
+OpenACC/ACC.cpp: ../../include/llvm/Frontend/OpenACC/ACC.td
+	$(call llvm_tblgen, $@, -gen-directive-impl $<)
+
+../../include/llvm/Frontend/OpenACC/ACC.h.inc: ../../include/llvm/Frontend/OpenACC/ACC.td
+	$(call llvm_tblgen, $@, -gen-directive-decl $<)
+
+OpenMP/OMP.cpp: ../../include/llvm/Frontend/OpenMP/OMP.td
+	$(call llvm_tblgen, $@, -gen-directive-impl $<)
+
+../../include/llvm/Frontend/OpenMP/OMP.cpp.inc: ../../include/llvm/Frontend/OpenMP/OMP.td
+	$(call llvm_tblgen, $@, -gen-directive-gen $<)
+
+../../include/llvm/Frontend/OpenMP/OMP.h.inc: ../../include/llvm/Frontend/OpenMP/OMP.td
+	$(call llvm_tblgen, $@, -gen-directive-decl $<)
+
 -include .depend.Windows
 
diff --git a/llvm/lib/IR/Makefile.Windows b/llvm/lib/IR/Makefile.Windows
index 4ec91ae..495cb6e 100644
--- a/llvm/lib/IR/Makefile.Windows
+++ b/llvm/lib/IR/Makefile.Windows
@@ -6,66 +6,82 @@ TARGETS = $(BUILD_DIR)/lib/LLVMCore.lib
 
 include $(TOP_DIR)/Common.Windows
 
-GENERATED += $(TOP_DIR)/llvm/lib/IR/AttributesCompatFunc.inc   \
-             $(TOP_DIR)/llvm/include/llvm/IR/IntrinsicImpl.inc \
-             $(TOP_DIR)/llvm/include/llvm/IR/IntrinsicEnums.inc
+GENERATED += $(TOP_DIR)/llvm/lib/IR/AttributesCompatFunc.inc \
+                                                             \
+             $(addprefix $(TOP_DIR)/llvm/include/llvm/IR/,   \
+               Attributes.inc                                \
+               IntrinsicImpl.inc                             \
+               IntrinsicEnums.inc                            \
+               IntrinsicsAArch64.h                           \
+               IntrinsicsAMDGPU.h                            \
+               IntrinsicsARM.h                               \
+               IntrinsicsBPF.h                               \
+               IntrinsicsHexagon.h                           \
+               IntrinsicsMips.h                              \
+               IntrinsicsNVPTX.h                             \
+               IntrinsicsPowerPC.h                           \
+               IntrinsicsR600.h                              \
+               IntrinsicsRISCV.h                             \
+               IntrinsicsS390.h                              \
+               IntrinsicsWebAssembly.h                       \
+               IntrinsicsX86.h                               \
+               IntrinsicsXCore.h)
 
-LIB_SRC =  AbstractCallSite.cpp    \
-           AsmWriter.cpp           \
-           Attributes.cpp          \
-           AutoUpgrade.cpp         \
-           BasicBlock.cpp          \
-           Comdat.cpp              \
-           ConstantFold.cpp        \
-           ConstantRange.cpp       \
-           Constants.cpp           \
-           Core.cpp                \
-           DIBuilder.cpp           \
-           DataLayout.cpp          \
-           DebugInfo.cpp           \
-           DebugInfoMetadata.cpp   \
-           DebugLoc.cpp            \
-           DiagnosticHandler.cpp   \
-           DiagnosticInfo.cpp      \
-           DiagnosticPrinter.cpp   \
-           Dominators.cpp          \
-           FPEnv.cpp               \
-           Function.cpp            \
-           GVMaterializer.cpp      \
-           Globals.cpp             \
-           IRBuilder.cpp           \
-           IRPrintingPasses.cpp    \
-           InlineAsm.cpp           \
-           Instruction.cpp         \
-           Instructions.cpp        \
-           IntrinsicInst.cpp       \
-           KnowledgeRetention.cpp  \
-           LLVMContext.cpp         \
-           LLVMContextImpl.cpp     \
-           LLVMRemarkStreamer.cpp  \
-           LegacyPassManager.cpp   \
-           MDBuilder.cpp           \
-           Mangler.cpp             \
-           Metadata.cpp            \
-           Module.cpp              \
-           ModuleSummaryIndex.cpp  \
-           Operator.cpp            \
-           OptBisect.cpp           \
-           Pass.cpp                \
-           PassInstrumentation.cpp \
-           PassManager.cpp         \
-           PassRegistry.cpp        \
-           PassTimingInfo.cpp      \
-           SafepointIRVerifier.cpp \
-           ProfileSummary.cpp      \
-           Statepoint.cpp          \
-           Type.cpp                \
-           TypeFinder.cpp          \
-           Use.cpp                 \
-           User.cpp                \
-           Value.cpp               \
-           ValueSymbolTable.cpp    \
-           Verifier.cpp
+LIB_SRC = AbstractCallSite.cpp    \
+          AsmWriter.cpp           \
+          Attributes.cpp          \
+          AutoUpgrade.cpp         \
+          BasicBlock.cpp          \
+          Comdat.cpp              \
+          ConstantFold.cpp        \
+          ConstantRange.cpp       \
+          Constants.cpp           \
+          Core.cpp                \
+          DIBuilder.cpp           \
+          DataLayout.cpp          \
+          DebugInfo.cpp           \
+          DebugInfoMetadata.cpp   \
+          DebugLoc.cpp            \
+          DiagnosticHandler.cpp   \
+          DiagnosticInfo.cpp      \
+          DiagnosticPrinter.cpp   \
+          Dominators.cpp          \
+          FPEnv.cpp               \
+          Function.cpp            \
+          GVMaterializer.cpp      \
+          Globals.cpp             \
+          IRBuilder.cpp           \
+          IRPrintingPasses.cpp    \
+          InlineAsm.cpp           \
+          Instruction.cpp         \
+          Instructions.cpp        \
+          IntrinsicInst.cpp       \
+          LLVMContext.cpp         \
+          LLVMContextImpl.cpp     \
+          LLVMRemarkStreamer.cpp  \
+          LegacyPassManager.cpp   \
+          MDBuilder.cpp           \
+          Mangler.cpp             \
+          Metadata.cpp            \
+          Module.cpp              \
+          ModuleSummaryIndex.cpp  \
+          Operator.cpp            \
+          OptBisect.cpp           \
+          Pass.cpp                \
+          PassInstrumentation.cpp \
+          PassManager.cpp         \
+          PassRegistry.cpp        \
+          PassTimingInfo.cpp      \
+          SafepointIRVerifier.cpp \
+          ProfileSummary.cpp      \
+          Statepoint.cpp          \
+          Type.cpp                \
+          TypeFinder.cpp          \
+          Use.cpp                 \
+          User.cpp                \
+          Value.cpp               \
+          ValueSymbolTable.cpp    \
+          Verifier.cpp
 
 ALL_SOURCES = $(LIB_SRC)
 
diff --git a/llvm/lib/MC/Makefile.Windows b/llvm/lib/MC/Makefile.Windows
index 4cd5c2f..66ed736 100644
--- a/llvm/lib/MC/Makefile.Windows
+++ b/llvm/lib/MC/Makefile.Windows
@@ -35,6 +35,7 @@ MC_SRC = ConstantPools.cpp               \
          MCInstPrinter.cpp               \
          MCInstrAnalysis.cpp             \
          MCInstrDesc.cpp                 \
+         MCInstrInfo.cpp                 \
          MCLabel.cpp                     \
          MCLinkerOptimizationHint.cpp    \
          MCMachOStreamer.cpp             \
@@ -55,6 +56,7 @@ MC_SRC = ConstantPools.cpp               \
          MCSubtargetInfo.cpp             \
          MCSymbol.cpp                    \
          MCSymbolELF.cpp                 \
+         MCSymbolXCOFF.cpp               \
          MCTargetOptions.cpp             \
          MCTargetOptionsCommandFlags.cpp \
          MCValue.cpp                     \
diff --git a/llvm/lib/ObjectYAML/Makefile.Windows b/llvm/lib/ObjectYAML/Makefile.Windows
index 57aef2b..9e3bfe4 100644
--- a/llvm/lib/ObjectYAML/Makefile.Windows
+++ b/llvm/lib/ObjectYAML/Makefile.Windows
@@ -13,15 +13,14 @@ LIB_SRC = CodeViewYAMLDebugSections.cpp \
           COFFEmitter.cpp               \
           COFFYAML.cpp                  \
           DWARFEmitter.cpp              \
-          DWARFVisitor.cpp              \
           DWARFYAML.cpp                 \
           ELFEmitter.cpp                \
           ELFYAML.cpp                   \
           MachOEmitter.cpp              \
           MachOYAML.cpp                 \
+          ObjectYAML.cpp                \
           MinidumpEmitter.cpp           \
           MinidumpYAML.cpp              \
-          ObjectYAML.cpp                \
           WasmEmitter.cpp               \
           WasmYAML.cpp                  \
           XCOFFYAML.cpp                 \
diff --git a/llvm/lib/Support/Makefile.Windows b/llvm/lib/Support/Makefile.Windows
index 6e37a9e..88fd96c 100644
--- a/llvm/lib/Support/Makefile.Windows
+++ b/llvm/lib/Support/Makefile.Windows
@@ -41,19 +41,23 @@ LIB_CPP_SRC = AArch64TargetParser.cpp          \
               CodeGenCoverage.cpp              \
               CommandLine.cpp                  \
               Compression.cpp                  \
+              CRC.cpp                          \
               ConvertUTF.cpp                   \
               ConvertUTFWrapper.cpp            \
               CrashRecoveryContext.cpp         \
-              CRC.cpp                          \
               DataExtractor.cpp                \
               Debug.cpp                        \
               DebugCounter.cpp                 \
               DeltaAlgorithm.cpp               \
               DAGDeltaAlgorithm.cpp            \
               DJB.cpp                          \
+              ELFAttributeParser.cpp           \
+              ELFAttributes.cpp                \
               Error.cpp                        \
               ErrorHandling.cpp                \
+              ExtensibleRTTI.cpp               \
               FileCheck.cpp                    \
+              FileCollector.cpp                \
               FileUtilities.cpp                \
               FileOutputBuffer.cpp             \
               FoldingSet.cpp                   \
@@ -75,16 +79,19 @@ LIB_CPP_SRC = AArch64TargetParser.cpp          \
               LowLevelType.cpp                 \
               ManagedStatic.cpp                \
               MathExtras.cpp                   \
+              MemAlloc.cpp                     \
               MemoryBuffer.cpp                 \
               MD5.cpp                          \
               NativeFormatting.cpp             \
+              OptimizedStructLayout.cpp        \
               Optional.cpp                     \
-              OptimalLayout.cpp                \
               Parallel.cpp                     \
               PluginLoader.cpp                 \
               PrettyStackTrace.cpp             \
               RandomNumberGenerator.cpp        \
               Regex.cpp                        \
+              RISCVAttributes.cpp              \
+              RISCVAttributeParser.cpp         \
               ScaledNumber.cpp                 \
               ScopedPrinter.cpp                \
               SHA1.cpp                         \
@@ -96,9 +103,9 @@ LIB_CPP_SRC = AArch64TargetParser.cpp          \
               Statistic.cpp                    \
               StringExtras.cpp                 \
               StringMap.cpp                    \
-              StringPool.cpp                   \
               StringSaver.cpp                  \
               StringRef.cpp                    \
+              SuffixTree.cpp                   \
               SymbolRemappingReader.cpp        \
               SystemUtils.cpp                  \
               TarWriter.cpp                    \
@@ -115,6 +122,7 @@ LIB_CPP_SRC = AArch64TargetParser.cpp          \
               VersionTuple.cpp                 \
               VirtualFileSystem.cpp            \
               WithColor.cpp                    \
+              X86TargetParser.cpp              \
               YAMLParser.cpp                   \
               YAMLTraits.cpp                   \
               raw_os_ostream.cpp               \
@@ -128,7 +136,6 @@ LIB_CPP_SRC = AArch64TargetParser.cpp          \
 LIB_CPP_SRC += Atomic.cpp         \
                DynamicLibrary.cpp \
                Errno.cpp          \
-               FileCollector.cpp  \
                Host.cpp           \
                Memory.cpp         \
                Path.cpp           \
diff --git a/llvm/lib/Target/Makefile.Windows b/llvm/lib/Target/Makefile.Windows
index 97a80e3..7cb06fe 100644
--- a/llvm/lib/Target/Makefile.Windows
+++ b/llvm/lib/Target/Makefile.Windows
@@ -129,9 +129,10 @@ CFLAGS += -I./AArch64     \
           -I./X86         \
           -I./XCore
 
-GENERATED += $(TOP_DIR)/llvm/include/llvm/IR/Attributes.inc     \
-             $(TOP_DIR)/llvm/include/llvm/IR/IntrinsicEnums.inc \
-             $(TOP_DIR)/llvm/include/llvm/IR/IntrinsicImpl.inc
+GENERATED += $(addprefix $(TOP_DIR)/llvm/include/llvm/IR/, \
+               Attributes.inc                              \
+               IntrinsicEnums.inc                          \
+               IntrinsicImpl.inc)
 
 GENERATED += $(addprefix AArch64/,              \
                AArch64GenAsmMatcher.inc         \
@@ -146,6 +147,8 @@ GENERATED += $(addprefix AArch64/,              \
                AArch64GenInstrInfo.inc          \
                AArch64GenMCCodeEmitter.inc      \
                AArch64GenMCPseudoLowering.inc   \
+               AArch64GenPostLegalizeGICombiner.inc \
+               AArch64GenPreLegalizeGICombiner.inc  \
                AArch64GenRegisterBank.inc       \
                AArch64GenRegisterInfo.inc       \
                AArch64GenSubtargetInfo.inc      \
@@ -164,13 +167,16 @@ GENERATED += $(addprefix AMDGPU/,                  \
                AMDGPUGenMCPseudoLowering.inc       \
                AMDGPUGenPostLegalizeGICombiner.inc \
                AMDGPUGenPreLegalizeGICombiner.inc  \
+               AMDGPUGenRegBankGICombiner.inc      \
                AMDGPUGenRegisterBank.inc           \
                AMDGPUGenRegisterInfo.inc           \
                AMDGPUGenSearchableTables.inc       \
                AMDGPUGenSubtargetInfo.inc          \
+               InstCombineTables.inc               \
                R600GenAsmWriter.inc                \
                R600GenCallingConv.inc              \
                R600GenDAGISel.inc                  \
+               R600GenDFAPacketizer.inc            \
                R600GenInstrInfo.inc                \
                R600GenMCCodeEmitter.inc            \
                R600GenRegisterInfo.inc             \
@@ -183,9 +189,6 @@ GENERATED += $(addprefix AMDGPU/,                  \
 # GENERATED += AMDGPU/AMDGPUGenIntrinsicEnums.inc
 # GENERATED += AMDGPU/AMDGPUGenGICombiner.inc
 #
-
-GENERATED += AMDGPU/R600GenDFAPacketizer.inc
-
 GENERATED += $(addprefix ARM/,                  \
                ARMGenAsmMatcher.inc             \
                ARMGenAsmWriter.inc              \
@@ -355,6 +358,7 @@ VPATH = $(addprefix AArch64/,      \
           .                        \
           AsmParser                \
           Disassembler             \
+          GISel                    \
           MCTargetDesc             \
           TargetInfo               \
           Utils)
@@ -475,7 +479,6 @@ AArch64CodeGen_SRC =          $(addprefix AArch64/,                    \
                                 AArch64AsmPrinter.cpp                  \
                                 AArch64BranchTargets.cpp               \
                                 AArch64CallingConvention.cpp           \
-                                AArch64CallLowering.cpp                \
                                 AArch64CleanupLocalDynamicTLSPass.cpp  \
                                 AArch64CollectLOH.cpp                  \
                                 AArch64CondBrTuning.cpp                \
@@ -493,17 +496,15 @@ AArch64CodeGen_SRC =          $(addprefix AArch64/,                    \
                                 AArch64ISelDAGToDAG.cpp                \
                                 AArch64ISelLowering.cpp                \
                                 AArch64InstrInfo.cpp                   \
-                                AArch64InstructionSelector.cpp         \
-                                AArch64LegalizerInfo.cpp               \
                                 AArch64LoadStoreOptimizer.cpp          \
+                                AArch64MachineFunctionInfo.cpp         \
                                 AArch64MacroFusion.cpp                 \
                                 AArch64MCInstLower.cpp                 \
-                                AArch64PreLegalizerCombiner.cpp        \
                                 AArch64PromoteConstant.cpp             \
                                 AArch64PBQPRegAlloc.cpp                \
-                                AArch64RegisterBankInfo.cpp            \
                                 AArch64RegisterInfo.cpp                \
                                 AArch64SelectionDAGInfo.cpp            \
+                                AArch64SLSHardening.cpp                \
                                 AArch64SpeculationHardening.cpp        \
                                 AArch64StackTagging.cpp                \
                                 AArch64StackTaggingPreRA.cpp           \
@@ -512,7 +513,16 @@ AArch64CodeGen_SRC =          $(addprefix AArch64/,                    \
                                 AArch64TargetMachine.cpp               \
                                 AArch64TargetObjectFile.cpp            \
                                 AArch64TargetTransformInfo.cpp         \
-                                AArch64SIMDInstrOpt.cpp)
+                                AArch64SIMDInstrOpt.cpp                \
+                                SVEIntrinsicOpts.cpp)
+
+AArch64CodeGen_SRC +=         $(addprefix AArch64/GISel/,              \
+                                AArch64CallLowering.cpp                \
+                                AArch64InstructionSelector.cpp         \
+                                AArch64LegalizerInfo.cpp               \
+                                AArch64PostLegalizerCombiner.cpp       \
+                                AArch64PreLegalizerCombiner.cpp        \
+                                AArch64RegisterBankInfo.cpp)
 
 AArch64AsmParser_SRC =        AArch64/AsmParser/AArch64AsmParser.cpp
 AArch64Disassembler_SRC =     AArch64/Disassembler/AArch64Disassembler.cpp \
@@ -544,10 +554,12 @@ AMDGPUCodeGen_SRC =           $(addprefix AMDGPU/,                    \
                                 AMDGPUAtomicOptimizer.cpp             \
                                 AMDGPUCallLowering.cpp                \
                                 AMDGPUCodeGenPrepare.cpp              \
+                                AMDGPUExportClustering.cpp            \
                                 AMDGPUFixFunctionBitcasts.cpp         \
                                 AMDGPUFrameLowering.cpp               \
                                 AMDGPUGlobalISelUtils.cpp             \
                                 AMDGPUHSAMetadataStreamer.cpp         \
+                                AMDGPUInstCombineIntrinsic.cpp        \
                                 AMDGPUInstrInfo.cpp                   \
                                 AMDGPUInstructionSelector.cpp         \
                                 AMDGPUISelDAGToDAG.cpp                \
@@ -607,6 +619,7 @@ AMDGPUCodeGen_SRC =           $(addprefix AMDGPU/,                    \
                                 SIFoldOperands.cpp                    \
                                 SIFormMemoryClauses.cpp               \
                                 SIFrameLowering.cpp                   \
+                                SIInsertHardClauses.cpp               \
                                 SIInsertSkips.cpp                     \
                                 SIInsertWaitcnts.cpp                  \
                                 SIInstrInfo.cpp                       \
@@ -694,6 +707,7 @@ ARMCodeGen_SRC =              $(addprefix ARM/,              \
                                 MVEGatherScatterLowering.cpp \
                                 MVETailPredication.cpp       \
                                 MVEVPTBlockPass.cpp          \
+                                MVEVPTOptimisationsPass.cpp  \
                                 Thumb1FrameLowering.cpp      \
                                 Thumb1InstrInfo.cpp          \
                                 ThumbRegisterInfo.cpp        \
@@ -755,6 +769,7 @@ BPFCodeGen_SRC =              $(addprefix BPF/,             \
                                 BPFISelLowering.cpp         \
                                 BPFMISimplifyPatchable.cpp  \
                                 BPFMCInstLower.cpp          \
+                                BPFPreserveDIType.cpp       \
                                 BPFRegisterInfo.cpp         \
                                 BPFSelectionDAGInfo.cpp     \
                                 BPFSubtarget.cpp            \
@@ -1004,20 +1019,18 @@ PowerPCCodeGen_SRC =          $(addprefix PowerPC/,        \
                                 PPCCTRLoops.cpp            \
                                 PPCHazardRecognizers.cpp   \
                                 PPCInstrInfo.cpp           \
-                                PPCMacroFusion.cpp         \
                                 PPCISelDAGToDAG.cpp        \
                                 PPCISelLowering.cpp        \
                                 PPCEarlyReturn.cpp         \
                                 PPCFastISel.cpp            \
                                 PPCFrameLowering.cpp       \
-                                PPCMachineScheduler.cpp    \
-                                PPCMachineFunctionInfo.cpp \
+                                PPCLoopInstrFormPrep.cpp   \
                                 PPCMCInstLower.cpp         \
+                                PPCMachineFunctionInfo.cpp \
+                                PPCMachineScheduler.cpp    \
+                                PPCMacroFusion.cpp         \
                                 PPCMIPeephole.cpp          \
-                                PPCLoopInstrFormPrep.cpp   \
-                                PPCLowerMASSVEntries.cpp   \
                                 PPCRegisterInfo.cpp        \
-                                PPCQPXLoadSplat.cpp        \
                                 PPCSubtarget.cpp           \
                                 PPCTargetMachine.cpp       \
                                 PPCTargetObjectFile.cpp    \
@@ -1029,7 +1042,8 @@ PowerPCCodeGen_SRC =          $(addprefix PowerPC/,        \
                                 PPCVSXFMAMutate.cpp        \
                                 PPCVSXSwapRemoval.cpp      \
                                 PPCExpandISEL.cpp          \
-                                PPCPreEmitPeephole.cpp)
+                                PPCPreEmitPeephole.cpp     \
+                                PPCLowerMASSVEntries.cpp)
 
 PowerPCDesc_SRC =             $(addprefix PowerPC/MCTargetDesc/, \
                                 PPCAsmBackend.cpp                \
@@ -1119,11 +1133,13 @@ WebAssemblyCodeGen_SRC =      $(addprefix WebAssembly/,                  \
                                 WebAssemblyAsmPrinter.cpp                \
                                 WebAssemblyCFGStackify.cpp               \
                                 WebAssemblyCFGSort.cpp                   \
+                                WebAssemblyDebugFixup.cpp                \
                                 WebAssemblyDebugValueManager.cpp         \
                                 WebAssemblyLateEHPrepare.cpp             \
                                 WebAssemblyExceptionInfo.cpp             \
                                 WebAssemblyExplicitLocals.cpp            \
                                 WebAssemblyFastISel.cpp                  \
+                                WebAssemblyFixBrTableDefaults.cpp        \
                                 WebAssemblyFixIrreducibleControlFlow.cpp \
                                 WebAssemblyFixFunctionBitcasts.cpp       \
                                 WebAssemblyFrameLowering.cpp             \
@@ -1135,7 +1151,6 @@ WebAssemblyCodeGen_SRC =      $(addprefix WebAssembly/,                  \
                                 WebAssemblyLowerGlobalDtors.cpp          \
                                 WebAssemblyMachineFunctionInfo.cpp       \
                                 WebAssemblyMCInstLower.cpp               \
-                                WebAssemblyMemIntrinsicResults.cpp       \
                                 WebAssemblyOptimizeLiveIntervals.cpp     \
                                 WebAssemblyOptimizeReturned.cpp          \
                                 WebAssemblyPeephole.cpp                  \
@@ -1148,6 +1163,8 @@ WebAssemblyCodeGen_SRC =      $(addprefix WebAssembly/,                  \
                                 WebAssemblyRuntimeLibcallSignatures.cpp  \
                                 WebAssemblySelectionDAGInfo.cpp          \
                                 WebAssemblySetP2AlignOperands.cpp        \
+                                WebAssemblySortRegion.cpp                \
+                                WebAssemblyMemIntrinsicResults.cpp       \
                                 WebAssemblySubtarget.cpp                 \
                                 WebAssemblyTargetMachine.cpp             \
                                 WebAssemblyTargetObjectFile.cpp          \
@@ -1167,55 +1184,58 @@ WebAssemblyAsmParser_SRC =    WebAssembly/AsmParser/WebAssemblyAsmParser.cpp
 WebAssemblyDisassembler_SRC = WebAssembly/Disassembler/WebAssemblyDisassembler.cpp
 WebAssemblyInfo_SRC =         WebAssembly/TargetInfo/WebAssemblyTargetInfo.cpp
 
-X86CodeGen_SRC =              $(addprefix X86/,                   \
-                                X86AsmPrinter.cpp                 \
-                                X86AvoidTrailingCall.cpp          \
-                                X86AvoidStoreForwardingBlocks.cpp \
-                                X86CallFrameOptimization.cpp      \
-                                X86CallingConv.cpp                \
-                                X86CallLowering.cpp               \
-                                X86CmovConversion.cpp             \
-                                X86CondBrFolding.cpp              \
-                                X86DomainReassignment.cpp         \
-                                X86DiscriminateMemOps.cpp         \
-                                X86ExpandPseudo.cpp               \
-                                X86FastISel.cpp                   \
-                                X86FixupBWInsts.cpp               \
-                                X86FixupLEAs.cpp                  \
-                                X86FixupSetCC.cpp                 \
-                                X86FlagsCopyLowering.cpp          \
-                                X86FloatingPoint.cpp              \
-                                X86FrameLowering.cpp              \
-                                X86InsertWait.cpp                 \
-                                X86InstructionSelector.cpp        \
-                                X86ISelDAGToDAG.cpp               \
-                                X86ISelLowering.cpp               \
-                                X86IndirectBranchTracking.cpp     \
-                                X86InterleavedAccess.cpp          \
-                                X86InsertPrefetch.cpp             \
-                                X86InstrFMA3Info.cpp              \
-                                X86InstrFoldTables.cpp            \
-                                X86InstrInfo.cpp                  \
-                                X86EvexToVex.cpp                  \
-                                X86LegalizerInfo.cpp              \
-                                X86MCInstLower.cpp                \
-                                X86MachineFunctionInfo.cpp        \
-                                X86MacroFusion.cpp                \
-                                X86OptimizeLEAs.cpp               \
-                                X86PadShortFunction.cpp           \
-                                X86PartialReduction.cpp           \
-                                X86RegisterBankInfo.cpp           \
-                                X86RegisterInfo.cpp               \
-                                X86RetpolineThunks.cpp            \
-                                X86SelectionDAGInfo.cpp           \
-                                X86ShuffleDecodeConstantPool.cpp  \
-                                X86SpeculativeLoadHardening.cpp   \
-                                X86Subtarget.cpp                  \
-                                X86TargetMachine.cpp              \
-                                X86TargetObjectFile.cpp           \
-                                X86TargetTransformInfo.cpp        \
-                                X86VZeroUpper.cpp                 \
-                                X86WinAllocaExpander.cpp          \
+X86CodeGen_SRC =              $(addprefix X86/,                                  \
+                                X86AsmPrinter.cpp                                \
+                                X86AvoidStoreForwardingBlocks.cpp                \
+                                X86AvoidTrailingCall.cpp                         \
+                                X86CallFrameOptimization.cpp                     \
+                                X86CallingConv.cpp                               \
+                                X86CallLowering.cpp                              \
+                                X86CmovConversion.cpp                            \
+                                X86DiscriminateMemOps.cpp                        \
+                                X86DomainReassignment.cpp                        \
+                                X86EvexToVex.cpp                                 \
+                                X86ExpandPseudo.cpp                              \
+                                X86FastISel.cpp                                  \
+                                X86FixupBWInsts.cpp                              \
+                                X86FixupLEAs.cpp                                 \
+                                X86FixupSetCC.cpp                                \
+                                X86FlagsCopyLowering.cpp                         \
+                                X86FloatingPoint.cpp                             \
+                                X86FrameLowering.cpp                             \
+                                X86IndirectBranchTracking.cpp                    \
+                                X86IndirectThunks.cpp                            \
+                                X86InsertPrefetch.cpp                            \
+                                X86InsertWait.cpp                                \
+                                X86InstCombineIntrinsic.cpp                      \
+                                X86InstrFMA3Info.cpp                             \
+                                X86InstrFoldTables.cpp                           \
+                                X86InstrInfo.cpp                                 \
+                                X86InstructionSelector.cpp                       \
+                                X86InterleavedAccess.cpp                         \
+                                X86ISelDAGToDAG.cpp                              \
+                                X86ISelLowering.cpp                              \
+                                X86LegalizerInfo.cpp                             \
+                                X86LoadValueInjectionLoadHardening.cpp           \
+                                X86LoadValueInjectionRetHardening.cpp            \
+                                X86MachineFunctionInfo.cpp                       \
+                                X86MacroFusion.cpp                               \
+                                X86MCInstLower.cpp                               \
+                                X86OptimizeLEAs.cpp                              \
+                                X86PadShortFunction.cpp                          \
+                                X86PartialReduction.cpp                          \
+                                X86RegisterBankInfo.cpp                          \
+                                X86RegisterInfo.cpp                              \
+                                X86SelectionDAGInfo.cpp                          \
+                                X86ShuffleDecodeConstantPool.cpp                 \
+                                X86SpeculativeExecutionSideEffectSuppression.cpp \
+                                X86SpeculativeLoadHardening.cpp                  \
+                                X86Subtarget.cpp                                 \
+                                X86TargetMachine.cpp                             \
+                                X86TargetObjectFile.cpp                          \
+                                X86TargetTransformInfo.cpp                       \
+                                X86VZeroUpper.cpp                                \
+                                X86WinAllocaExpander.cpp                         \
                                 X86WinEHState.cpp)
 
 X86Desc_SRC =                 $(addprefix X86/MCTargetDesc/, \
@@ -1807,7 +1827,7 @@ AArch64/AArch64GenGlobalISel.inc: $(Aaach64_DEPS)
 	$(call llvm_tblgen, $@, -gen-global-isel $<)
 
 AArch64/AArch64GenInstrInfo.inc: $(Aaach64_DEPS)
-	$(call llvm_tblgen, $@, -gen-instr-info $<)
+	$(call llvm_tblgen, $@, -gen-instr-info $(EXTRA_TBLGEN_FLAGS) $<)
 
 AArch64/AArch64GenMCCodeEmitter.inc: $(Aaach64_DEPS)
 	$(call llvm_tblgen, $@, -gen-emitter $<)
@@ -1815,6 +1835,12 @@ AArch64/AArch64GenMCCodeEmitter.inc: $(Aaach64_DEPS)
 AArch64/AArch64GenMCPseudoLowering.inc: $(Aaach64_DEPS)
 	$(call llvm_tblgen, $@, -gen-pseudo-lowering $<)
 
+AArch64/AArch64GenPostLegalizeGICombiner.inc: $(Aaach64_DEPS)
+	$(call llvm_tblgen, $@, -gen-global-isel-combiner -combiners=AArch64PostLegalizerCombinerHelper $<)
+
+AArch64/AArch64GenPreLegalizeGICombiner.inc: $(Aaach64_DEPS)
+	$(call llvm_tblgen, $@, -gen-global-isel-combiner -combiners=AArch64PreLegalizerCombinerHelper $<)
+
 AArch64/AArch64GenRegisterBank.inc: $(Aaach64_DEPS)
 	$(call llvm_tblgen, $@, -gen-register-bank $<)
 
@@ -1877,6 +1903,9 @@ AMDGPU/AMDGPUGenPostLegalizeGICombiner.inc: AMDGPU/AMDGPUGISel.td $(AMDGPU_DEPS)
 AMDGPU/AMDGPUGenGlobalISel.inc: AMDGPU/AMDGPUGISel.td $(AMDGPU_DEPS)
 	$(call llvm_tblgen, $@, -gen-global-isel $<)
 
+AMDGPU/AMDGPUGenRegBankGICombiner.inc: AMDGPU/AMDGPUGISel.td $(AMDGPU_DEPS)
+	$(call llvm_tblgen, $@, -gen-global-isel-combiner -combiners=AMDGPURegBankCombinerHelper $<)
+
 AMDGPU/AMDGPUGenRegisterBank.inc: $(AMDGPU_DEPS)
 	$(call llvm_tblgen, $@, -gen-register-bank $<)
 
@@ -1889,6 +1918,9 @@ AMDGPU/AMDGPUGenSearchableTables.inc: $(AMDGPU_DEPS)
 AMDGPU/AMDGPUGenSubtargetInfo.inc: $(AMDGPU_DEPS)
 	$(call llvm_tblgen, $@, -gen-subtarget $<)
 
+AMDGPU/InstCombineTables.inc: InstCombineTables.td $(AMDGPU_DEPS)
+	$(call llvm_tblgen, $@, -gen-searchable-tables $<)
+
 AMDGPU/R600GenAsmWriter.inc: $(R600_DEPS)
 	$(call llvm_tblgen, $@, -gen-asm-writer $<)
 
@@ -2423,7 +2455,7 @@ DEP_CFLAGS += $(addprefix -I./,                                   \
                 WebAssembly    X86    XCore)
 
 define depend_chunk
-  $(call colour_msg,$(BRIGHT_GREEN)chunk with $(BRIGHT_YELLOW)$(words $(1))$(BRIGHT_GREEN) files...)
+  $(call green_msg, Generating dependencies for chunk with $(BRIGHT_YELLOW)$(words $(1))$(BRIGHT_GREEN) files...)
   $(call create_rsp_file, depend.args, $(DEP_CFLAGS) $(1))
   g++ @depend.args | sed $(DEP_REPLACE) >> .depend.Windows
 endef
diff --git a/llvm/lib/Transforms/IPO/Makefile.Windows b/llvm/lib/Transforms/IPO/Makefile.Windows
index 45e4907..1ed9998 100644
--- a/llvm/lib/Transforms/IPO/Makefile.Windows
+++ b/llvm/lib/Transforms/IPO/Makefile.Windows
@@ -9,6 +9,7 @@ include $(TOP_DIR)/Common.Windows
 LIB_SRC = AlwaysInliner.cpp              \
           ArgumentPromotion.cpp          \
           Attributor.cpp                 \
+          AttributorAttributes.cpp       \
           BarrierNoopPass.cpp            \
           BlockExtractor.cpp             \
           CalledValuePropagation.cpp     \
@@ -28,7 +29,6 @@ LIB_SRC = AlwaysInliner.cpp              \
           Inliner.cpp                    \
           InlineSimple.cpp               \
           Internalize.cpp                \
-          IPConstantPropagation.cpp      \
           IPO.cpp                        \
           LoopExtractor.cpp              \
           LowerTypeTests.cpp             \
diff --git a/llvm/lib/Transforms/InstCombine/Makefile.Windows b/llvm/lib/Transforms/InstCombine/Makefile.Windows
index bbb10ee..92a1915 100644
--- a/llvm/lib/Transforms/InstCombine/Makefile.Windows
+++ b/llvm/lib/Transforms/InstCombine/Makefile.Windows
@@ -6,8 +6,6 @@ TARGETS = $(BUILD_DIR)/lib/LLVMInstCombine.lib
 
 include $(TOP_DIR)/Common.Windows
 
-GENERATED += InstCombineTables.inc
-
 LIB_SRC = InstructionCombining.cpp        \
           InstCombineAddSub.cpp           \
           InstCombineAndOrXor.cpp         \
@@ -17,6 +15,7 @@ LIB_SRC = InstructionCombining.cpp        \
           InstCombineCompares.cpp         \
           InstCombineLoadStoreAlloca.cpp  \
           InstCombineMulDivRem.cpp        \
+          InstCombineNegator.cpp          \
           InstCombinePHI.cpp              \
           InstCombineSelect.cpp           \
           InstCombineShifts.cpp           \
@@ -37,8 +36,5 @@ endif
 $(BUILD_DIR)/lib/LLVMInstCombine.lib: $(LIB_OBJ)
 	 $(call create_lib, $@, $^)
 
-InstCombineTables.inc: InstCombineTables.td $(INC_DEPS)
-	$(call llvm_tblgen, $@, -gen-searchable-tables $<)
-
 -include .depend.Windows
 
diff --git a/llvm/lib/Transforms/Utils/Makefile.Windows b/llvm/lib/Transforms/Utils/Makefile.Windows
index 7dc4b80..4022cd0 100644
--- a/llvm/lib/Transforms/Utils/Makefile.Windows
+++ b/llvm/lib/Transforms/Utils/Makefile.Windows
@@ -9,13 +9,15 @@ include $(TOP_DIR)/Common.Windows
 LIB_SRC = AddDiscriminators.cpp                   \
           AMDGPUEmitPrintf.cpp                    \
           ASanStackFrameLayout.cpp                \
+          AssumeBundleBuilder.cpp                 \
           BasicBlockUtils.cpp                     \
           BreakCriticalEdges.cpp                  \
           BuildLibCalls.cpp                       \
           BypassSlowDivision.cpp                  \
-          CallGraphUpdater.cpp                    \
           CallPromotionUtils.cpp                  \
+          CallGraphUpdater.cpp                    \
           CanonicalizeAliases.cpp                 \
+          CanonicalizeFreezeInLoops.cpp           \
           CloneFunction.cpp                       \
           CloneModule.cpp                         \
           CodeExtractor.cpp                       \
@@ -26,30 +28,32 @@ LIB_SRC = AddDiscriminators.cpp                   \
           EntryExitInstrumenter.cpp               \
           EscapeEnumerator.cpp                    \
           Evaluator.cpp                           \
+          FixIrreducible.cpp                      \
           FlattenCFG.cpp                          \
           FunctionComparator.cpp                  \
           FunctionImportUtils.cpp                 \
           GlobalStatus.cpp                        \
           GuardUtils.cpp                          \
+          InlineFunction.cpp                      \
           ImportedFunctionsInliningStatistics.cpp \
           InjectTLIMappings.cpp                   \
-          InlineFunction.cpp                      \
           InstructionNamer.cpp                    \
           IntegerDivision.cpp                     \
           LCSSA.cpp                               \
           LibCallsShrinkWrap.cpp                  \
           Local.cpp                               \
+          LoopPeel.cpp                            \
           LoopRotationUtils.cpp                   \
           LoopSimplify.cpp                        \
           LoopUnroll.cpp                          \
           LoopUnrollAndJam.cpp                    \
-          LoopUnrollPeel.cpp                      \
           LoopUnrollRuntime.cpp                   \
           LoopUtils.cpp                           \
           LoopVersioning.cpp                      \
           LowerInvoke.cpp                         \
           LowerMemIntrinsics.cpp                  \
           LowerSwitch.cpp                         \
+          MatrixUtils.cpp                         \
           Mem2Reg.cpp                             \
           MetaRenamer.cpp                         \
           MisExpect.cpp                           \
@@ -57,18 +61,21 @@ LIB_SRC = AddDiscriminators.cpp                   \
           NameAnonGlobals.cpp                     \
           PredicateInfo.cpp                       \
           PromoteMemoryToRegister.cpp             \
+          ScalarEvolutionExpander.cpp             \
+          StripGCRelocates.cpp                    \
+          SSAUpdater.cpp                          \
+          SSAUpdaterBulk.cpp                      \
           SanitizerStats.cpp                      \
           SimplifyCFG.cpp                         \
           SimplifyIndVar.cpp                      \
           SimplifyLibCalls.cpp                    \
           SizeOpts.cpp                            \
           SplitModule.cpp                         \
-          SSAUpdater.cpp                          \
-          SSAUpdaterBulk.cpp                      \
-          StripGCRelocates.cpp                    \
           StripNonLineTableDebugInfo.cpp          \
           SymbolRewriter.cpp                      \
           UnifyFunctionExitNodes.cpp              \
+          UnifyLoopExits.cpp                      \
+          UniqueInternalLinkageNames.cpp          \
           Utils.cpp                               \
           ValueMapper.cpp                         \
           VNCoercion.cpp
diff --git a/llvm/lib/WindowsManifest/Makefile.Windows b/llvm/lib/WindowsManifest/Makefile.Windows
index f4166dc..7f30c60 100644
--- a/llvm/lib/WindowsManifest/Makefile.Windows
+++ b/llvm/lib/WindowsManifest/Makefile.Windows
@@ -7,8 +7,9 @@ TARGETS = $(BUILD_DIR)/lib/LLVMWindowsManifest.lib
 include $(TOP_DIR)/Common.Windows
 
 ifeq ($(USE_XML2),1)
-  CFLAGS += -I$(XML2_ROOT)/include \
-            -I$(ICONV_ROOT)/include
+  CFLAGS += -I$(XML2_ROOT)/include  \
+            -I$(ICONV_ROOT)/include \
+            -DLIBXML_STATIC
 endif
 
 ALL_SOURCES = WindowsManifestMerger.cpp
diff --git a/llvm/tools/lli/Makefile.Windows b/llvm/tools/lli/Makefile.Windows
index b20267f..a7ebdda 100644
--- a/llvm/tools/lli/Makefile.Windows
+++ b/llvm/tools/lli/Makefile.Windows
@@ -58,8 +58,12 @@ lli-LIBS = $(addprefix $(BUILD_DIR)/lib/, \
              LLVMX86Utils.lib)
 
 lli-child-target-LIBS = $(addprefix $(BUILD_DIR)/lib/, \
+                          LLVMCore.lib                 \
+                          LLVMBinaryFormat.lib         \
+                          LLVMBitstreamReader.lib      \
                           LLVMOrcError.lib             \
                           LLVMRuntimeDyld.lib          \
+                          LLVMRemarks.lib              \
                           LLVMSupport.lib)
 
 #
diff --git a/llvm/tools/llvm-config/Makefile.Windows b/llvm/tools/llvm-config/Makefile.Windows
index fdd3fbf..4e9f24c 100644
--- a/llvm/tools/llvm-config/Makefile.Windows
+++ b/llvm/tools/llvm-config/Makefile.Windows
@@ -7,8 +7,9 @@ MDEPEND = $(THIS_FILE)
 
 include $(TOP_DIR)/Common.Windows
 
-GENERATED += BuildVariables.inc \
-             LibraryDependencies.inc
+GENERATED += BuildVariables.inc      \
+             LibraryDependencies.inc \
+             ExtensionDependencies.inc
 
 ALL_SOURCES = llvm-config.cpp
 OBJECTS     = $(call cpp_to_obj, $(ALL_SOURCES))
@@ -45,6 +46,23 @@ LibraryDependencies.inc: ../../utils/llvm-build/llvm-build ../../utils/llvm-buil
 	rm -f ./tmp/LibraryDependencies.tmp
 	rmdir ./tmp
 
+#
+# For now, just create this minimal file
+#
+ExtensionDependencies.inc: $(THIS_FILE)
+	$(call Generating, $@, //)
+	$(file >> $@,$(ExtensionDependencies_INC))
+
+define ExtensionDependencies_INC
+  #include <array>
+  struct ExtensionDescriptor {
+              const char *Name;
+              const char *RequiredLibraries[2];
+           };
+  std::array <ExtensionDescriptor, 0> AvailableExtensions {
+  };
+endef
+
 ifeq ($(USE_ZLIB),1)
   LLVM_SYSTEM_LIBS = "zlib.lib"
 endif
@@ -61,9 +79,9 @@ define BuildVariables_INC
   #define LLVM_LDFLAGS            "$(LDFLAGS)"
 
   #if ($(USE_CRT_DEBUG) == 1)
-    #define LLVM_BUILDMODE        "Debug"
+    #define LLVM_BUILDMODE        "Debug"    // 'USE_CRT_DEBUG = 1'
   #else
-    #define LLVM_BUILDMODE        "Release"
+    #define LLVM_BUILDMODE        "Release"  // 'USE_CRT_DEBUG = 0'
   #endif
 
   #define LLVM_LIBDIR_SUFFIX      ""
diff --git a/llvm/tools/llvm-dwarfdump/Makefile.Windows b/llvm/tools/llvm-dwarfdump/Makefile.Windows
index 3390dea..2f1f044 100644
--- a/llvm/tools/llvm-dwarfdump/Makefile.Windows
+++ b/llvm/tools/llvm-dwarfdump/Makefile.Windows
@@ -7,6 +7,7 @@ TARGETS = $(BUILD_DIR)/bin/llvm-dwarfdump.exe
 include $(TOP_DIR)/Common.Windows
 
 ALL_SOURCES = llvm-dwarfdump.cpp \
+              SectionSizes.cpp   \
               Statistics.cpp
 
 OBJECTS = $(call cpp_to_obj, $(ALL_SOURCES))
diff --git a/llvm/tools/llvm-link/Makefile.Windows b/llvm/tools/llvm-link/Makefile.Windows
index 6355b48..0e9def6 100644
--- a/llvm/tools/llvm-link/Makefile.Windows
+++ b/llvm/tools/llvm-link/Makefile.Windows
@@ -29,9 +29,9 @@ LIBS = $(addprefix $(BUILD_DIR)/lib/, \
          LLVMProfileData.lib          \
          LLVMRemarks.lib              \
          LLVMSupport.lib              \
+         LLVMTextAPI.lib              \
          LLVMTransformUtils.lib)
 
-
 #
 # External libraries needed:
 #
diff --git a/llvm/tools/llvm-objdump/Makefile.Windows b/llvm/tools/llvm-objdump/Makefile.Windows
index d08fd77..10ea6c4 100644
--- a/llvm/tools/llvm-objdump/Makefile.Windows
+++ b/llvm/tools/llvm-objdump/Makefile.Windows
@@ -10,7 +10,8 @@ ALL_SOURCES = COFFDump.cpp     \
               ELFDump.cpp      \
               llvm-objdump.cpp \
               MachODump.cpp    \
-              WasmDump.cpp
+              WasmDump.cpp     \
+              XCOFFDump.cpp
 
 OBJECTS = $(call cpp_to_obj, $(ALL_SOURCES))
 
diff --git a/llvm/tools/llvm-reduce/Makefile.Windows b/llvm/tools/llvm-reduce/Makefile.Windows
index d243042..96c76c9 100644
--- a/llvm/tools/llvm-reduce/Makefile.Windows
+++ b/llvm/tools/llvm-reduce/Makefile.Windows
@@ -8,17 +8,20 @@ VPATH = deltas
 
 include $(TOP_DIR)/Common.Windows
 
-ALL_SOURCES = llvm-reduce.cpp          \
-              TestRunner.cpp           \
-                                       \
-              $(addprefix deltas/,     \
-                Delta.cpp              \
-                ReduceArguments.cpp    \
-                ReduceBasicBlocks.cpp  \
-                ReduceFunctions.cpp    \
-                ReduceGlobalVars.cpp   \
-                ReduceInstructions.cpp \
-                ReduceMetadata.cpp)
+ALL_SOURCES = llvm-reduce.cpp            \
+              TestRunner.cpp             \
+                                         \
+              $(addprefix deltas/,       \
+                Delta.cpp                \
+                ReduceArguments.cpp      \
+                ReduceAttributes.cpp     \
+                ReduceBasicBlocks.cpp    \
+                ReduceFunctionBodies.cpp \
+                ReduceFunctions.cpp      \
+                ReduceGlobalVars.cpp     \
+                ReduceInstructions.cpp   \
+                ReduceMetadata.cpp       \
+                ReduceOperandBundles.cpp)
 
 OBJECTS = $(call cpp_to_obj, $(ALL_SOURCES))
 
diff --git a/llvm/tools/llvm-shlib/Makefile.Windows b/llvm/tools/llvm-shlib/Makefile.Windows
index 19e8d1f..5ed16b5 100644
--- a/llvm/tools/llvm-shlib/Makefile.Windows
+++ b/llvm/tools/llvm-shlib/Makefile.Windows
@@ -3,6 +3,8 @@
 #
 TOP_DIR = ../../..
 
+USE_CHECK_LIBS = 0
+
 LLVM_DLL     = $(BUILD_DIR)/bin/LLVM-C.dll
 LLVM_IMP_LIB = $(BUILD_DIR)/lib/LLVM-C.lib
 
@@ -29,8 +31,10 @@ ALL_LLVM_LIBS = $(wildcard $(BUILD_DIR)/lib/LLVM*.lib)
 #
 # Except these:
 #
-ALL_LLVM_LIBS := $(filter-out $(LLVM_IMP_LIB), $(ALL_LLVM_LIBS))
-ALL_LLVM_LIBS := $(filter-out $(BUILD_DIR)/lib/LLVM-Remarks.lib, $(ALL_LLVM_LIBS))
+except_these = $(LLVM_IMP_LIB) \
+               $(BUILD_DIR)/lib/LLVM-Remarks.lib
+
+ALL_LLVM_LIBS := $(filter-out $(except_these), $(ALL_LLVM_LIBS))
 
 #
 # Needed in 'LLVMSupport.lib (Path.obj)'
@@ -60,7 +64,7 @@ $(LLVM_DLL): $(OBJECTS) $(OBJ_DIR)/LLVM-C.res $(OBJ_DIR)/LLVM-C.def $(ALL_LLVM_L
 	                                      -def:$(OBJ_DIR)/LLVM-C.def $(ALL_LLVM_LIBS) $(EX_LIBS))
 
 #
-# Use 'link.args' as the temporary responce-file here.
+# Use 'link.args' as the temporary response-file here.
 # It will be overwritten by '$(call link_DLL)' above.
 #
 $(OBJ_DIR)/LLVM-C.def: $(MDEPEND) $(BUILD_DIR)/bin/llvm-nm.exe
diff --git a/llvm/tools/llvm-symbolizer/Makefile.Windows b/llvm/tools/llvm-symbolizer/Makefile.Windows
index 64df7e8..525c3bd 100644
--- a/llvm/tools/llvm-symbolizer/Makefile.Windows
+++ b/llvm/tools/llvm-symbolizer/Makefile.Windows
@@ -1,8 +1,9 @@
 #
 # GNU Makefile for 'llvm/tools/llvm-symbolizer'.
 #
-TOP_DIR = ../../..
-TARGETS = $(BUILD_DIR)/bin/llvm-symbolizer.exe
+TOP_DIR   = ../../..
+TARGETS   = $(BUILD_DIR)/bin/llvm-symbolizer.exe
+GENERATED = Opts.inc
 
 include $(TOP_DIR)/Common.Windows
 
@@ -24,6 +25,7 @@ LIBS = $(addprefix $(BUILD_DIR)/lib/, \
          LLVMMC.lib                   \
          LLVMMCParser.lib             \
          LLVMObject.lib               \
+         LLVMOption.lib               \
          LLVMRemarks.lib              \
          LLVMSupport.lib              \
          LLVMSymbolize.lib            \
@@ -47,5 +49,8 @@ $(BUILD_DIR)/bin/llvm-symbolizer.exe: $(OBJECTS) $(LIBS) $(OBJ_DIR)/llvm-symboli
 $(OBJ_DIR)/llvm-symbolizer.rc: $(MDEPEND)
 	$(call make_rc, $@, llvm-symbolizer.exe, VFT_APP, Address to symbol location tool.)
 
+Opts.inc: Opts.td $(BUILD_DIR)/bin/llvm-tblgen.exe
+	$(call llvm_tblgen, $@, -gen-opt-parser-defs $<)
+
 -include .depend.Windows
 
diff --git a/llvm/utils/TableGen/Makefile.Windows b/llvm/utils/TableGen/Makefile.Windows
index 63e3755..8d93c86 100644
--- a/llvm/utils/TableGen/Makefile.Windows
+++ b/llvm/utils/TableGen/Makefile.Windows
@@ -28,6 +28,7 @@ ALL_SOURCES = AsmMatcherEmitter.cpp              \
               DAGISelMatcherOpt.cpp              \
               DFAEmitter.cpp                     \
               DFAPacketizerEmitter.cpp           \
+              DirectiveEmitter.cpp               \
               DisassemblerEmitter.cpp            \
               ExegesisEmitter.cpp                \
               FastISelEmitter.cpp                \
