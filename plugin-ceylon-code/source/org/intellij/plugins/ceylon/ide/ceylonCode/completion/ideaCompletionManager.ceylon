import ceylon.interop.java {
    Iter=CeylonIterable
}

import com.intellij.codeInsight.completion {
    CompletionParameters,
    CompletionResultSet,
    InsertHandler
}
import com.intellij.codeInsight.lookup {
    LookupElementBuilder,
    LookupElement
}
import com.intellij.openapi.editor {
    Document,
    Editor
}
import com.intellij.openapi.\imodule {
    Module
}
import com.intellij.openapi.util {
    TextRange
}
import com.intellij.util {
    ProcessingContext,
    PlatformIcons
}
import com.redhat.ceylon.cmr.api {
    ModuleVersionDetails,
    ModuleSearchResult
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.completion {
    IdeCompletionManager
}
import com.redhat.ceylon.ide.common.model {
    CeylonProject
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    ProgressMonitor,
    Indents
}
import com.redhat.ceylon.model.typechecker.model {
    Function,
    Value,
    Declaration,
    Class,
    Interface,
    TypeAlias,
    Unit,
    Scope,
    Type,
    Reference,
    Package
}

import java.util {
    JList=List
}
import java.util.regex {
    Pattern
}

import javax.swing {
    Icon
}

import org.antlr.runtime {
    CommonToken
}
import org.intellij.plugins.ceylon.ide.ceylonCode.psi {
    CeylonFile
}
import org.intellij.plugins.ceylon.ide.ceylonCode.util {
    ideaIcons,
    ideaIndents
}

shared class CompletionData(shared actual PhasedUnit lastPhasedUnit, shared Editor editor,
        shared actual TypeChecker typeChecker, shared CeylonFile file)
        satisfies LocalAnalysisResult<Document,Module> {
    shared actual Tree.CompilationUnit lastCompilationUnit => lastPhasedUnit.compilationUnit;
    shared actual Tree.CompilationUnit parsedRootNode => lastCompilationUnit;
    shared actual Tree.CompilationUnit? typecheckedRootNode => lastCompilationUnit;
    shared actual Document document => editor.document;
    shared actual JList<CommonToken>? tokens => lastPhasedUnit.tokens;
    shared actual CeylonProject<Module>? ceylonProject => null;// TODO
}

shared object ideaCompletionManager extends IdeCompletionManager<CompletionData,Module,LookupElement,Document>() {
    
    shared void addCompletions(CompletionParameters parameters, ProcessingContext context, CompletionResultSet result,
            PhasedUnit pu, TypeChecker tc) {
        value isSecondLevel = parameters.invocationCount > 0 && parameters.invocationCount % 2 == 0;
        value element = parameters.originalPosition;
        value doc = parameters.editor.document;
        assert(is CeylonFile ceylonFile = element.containingFile);
        value params = CompletionData(pu, parameters.editor, tc, ceylonFile);
        value line = doc.getLineNumber(element.textOffset);
        
        value monitor = object satisfies ProgressMonitor {
            shared actual variable Integer workRemaining = 100;
            shared actual void worked(Integer amount) {
                workRemaining -= amount;
            }
            shared actual void subTask(String? desc) {}
        };
        value returnedParamInfo = true; // The parameters tooltip has nothing to do with code completion, so we bypass it
        value completions = getContentProposals(pu.compilationUnit, params, 
            parameters.editor.caretModel.offset, line, isSecondLevel, monitor, returnedParamInfo);
        
        CustomLookupCellRenderer.install(parameters.editor.project);
        
        for (completion in completions) {
            result.addElement(completion);
        }
        
        if (!isSecondLevel) {
            result.addLookupAdvertisement("Call again to toggle second-level completions");
        }
    }
    
    shared actual List<Pattern> proposalFilters => empty;
    shared actual Boolean showParameterTypes => true;
    shared actual String inexactMatches => "positional";
    shared actual Boolean supportsLinkedModeInArguments => false;
    shared actual Boolean addParameterTypesInCompletions => true;
    shared actual Indents<Document> indents => ideaIndents;
    
    shared actual LookupElement newParametersCompletionProposal(Integer offset,
        Type type, JList<Type> argTypes, Node node, CompletionData data) {
        
        print("newParametersCompletionProposal");
        return MyLookupElementBuilder(type.declaration, node.unit, true).lookupElement;
    }
    
    shared actual String getDocumentSubstring(Document doc, Integer start, Integer length)
            => doc.getText(TextRange.from(start, length));
    
    shared actual LookupElement newPositionalInvocationCompletion(Integer offset, String prefix,
        String desc, String text, Declaration dec, Reference? pr, Scope scope, CompletionData data,
        Boolean isMember, String? typeArgs, Boolean includeDefaulted, Declaration? qualifyingDec) {
        
        //print("newPositionalInvocationCompletion ``dec`` - ``typeArgs else "null"``");
        //return MyLookupElementBuilder(dec, dec.unit, true, typeArgs, qualifyingDec).lookupElement;
        return IdeaInvocationCompletionProposal(offset, prefix, desc, text, dec, pr, scope,
            includeDefaulted, true, false, isMember, qualifyingDec, data).lookupElement;
    }
    
    shared actual LookupElement newNamedInvocationCompletion(Integer offset, String prefix,
        String desc, String text, Declaration dec, Reference? pr, Scope scope, CompletionData data,
        Boolean isMember, String? typeArgs, Boolean includeDefaulted) {
        
        //print("newNamedInvocationCompletion");
        assert(exists pr);
        
        return IdeaInvocationCompletionProposal(offset, prefix, desc, text, dec, pr, scope,
            includeDefaulted, false, true, isMember, null, data).lookupElement;
    }
    
    shared actual LookupElement newReferenceCompletion(Integer offset, String prefix,
        String desc, String text, Declaration dec, Unit u, Reference? pr, Scope scope,
        CompletionData data, Boolean isMember, Boolean includeTypeArgs) {
        
        //print("newReferenceCompletion ``includeTypeArgs``");
        return IdeaInvocationCompletionProposal(offset, prefix, desc, text, dec, pr, scope,
            true, false, false, isMember, null, data).lookupElement;
    }
    
    shared actual LookupElement newRefinementCompletionProposal(Integer offset, String prefix,
        Reference? pr, String desc, String text, CompletionData data,
        Declaration dec, Scope scope, Boolean fullType, Boolean explicitReturnType) {
        
        assert(exists pr);
        return IdeaRefinementCompletionProposal(offset, prefix, pr, desc, text,
            data, dec, scope, fullType, explicitReturnType).lookupElement;
    }
    
    shared actual LookupElement newMemberNameCompletionProposal(Integer offset, String prefix, String name, String unquotedName) {
        //print("newMemberNameCompletionProposal");
        
        return LookupElementBuilder.create(unquotedName, name)
            .withIcon(ideaIcons.local);
    }
    
    shared actual LookupElement newKeywordCompletionProposal(Integer offset, String prefix, String keyword, String text) {
        value selection = if (exists close = text.firstOccurrence(')'))
            then TextRange.from(offset + close - prefix.size, 0)
            else null;
        
        return newLookup(keyword, text, ideaIcons.correction, null, selection);
    }
    
    shared actual LookupElement newAnonFunctionProposal(Integer offset, Type? requiredType,
        Unit unit, String text, String header, Boolean isVoid,
        Integer selectionStart, Integer selectionLength) {
        
        return newLookup(text, text, ideaIcons.correction, 
            null, TextRange.from(selectionStart, selectionLength));
    }
    
    shared actual LookupElement newProgramElementReferenceCompletion(Integer offset, String prefix,
        String name, String desc, Declaration dec, Reference? pr, Scope scope, CompletionData data, Boolean isMember) {
        
        return IdeaInvocationCompletionProposal(offset, prefix, name, desc,
            dec, dec.reference, scope, true, false, false, isMember, null, data).lookupElement;
    }
    
    shared actual LookupElement newBasicCompletionProposal(Integer offset,
        String prefix, String text, String escapedText, Declaration decl,
        CompletionData data) {

        return newLookup(escapedText, text, ideaIcons.forDeclaration(decl));
    }
    
    shared actual LookupElement newPackageDescriptorProposal(Integer offset, String prefix, String desc, String text) {
        return newLookup(desc, text);
    }
    
    shared actual LookupElement newCurrentPackageProposal(Integer offset, String prefix, String packageName, CompletionData data) {
        return LookupElementBuilder.create(packageName)
            .withIcon(ideaIcons.packages);
    }

    shared actual LookupElement newImportedModulePackageProposal(Integer offset, String prefix,
        String memberPackageSubname, Boolean withBody,
        String fullPackageName, CompletionData data,
        Package candidate) {
        
        return IdeaImportedModulePackageProposal(offset, prefix, memberPackageSubname,
            withBody, fullPackageName, data, candidate).lookupElement;
    }
    
    shared actual LookupElement newQueriedModulePackageProposal(Integer offset, String prefix,
        String memberPackageSubname, Boolean withBody,
        String fullPackageName, CompletionData data,
        ModuleVersionDetails version, Unit unit, ModuleSearchResult.ModuleDetails md) {
     
        print("newQueriedModulePackageProposal");
        return LookupElementBuilder.create(memberPackageSubname);
    }       
    
    shared actual LookupElement newModuleProposal(Integer offset, String prefix, Integer len, 
        String versioned, ModuleSearchResult.ModuleDetails mod,
        Boolean withBody, ModuleVersionDetails version, String name, Node node) {
        
        //print("newModuleProposal");
        // TODO abstraction
        return LookupElementBuilder.create(versioned)
                .withIcon(ideaIcons.modules);
    }
    
    shared actual LookupElement newModuleDescriptorProposal(Integer offset, String prefix, String desc,
        String text, Integer selectionStart, Integer selectionEnd) {
        return newLookup(desc, text)
                .withIcon(ideaIcons.modules);
        // TODO selection
    }

    shared actual LookupElement newJDKModuleProposal(Integer offset, String prefix, Integer len, 
        String versioned, String name) {

        //print("newJDKModuleProposal");
        return LookupElementBuilder.create(versioned)
                .withPresentableText(versioned.spanFrom(len))
                .withIcon(ideaIcons.modules);
    }

    // Not supported in IntelliJ (see CeylonParameterInfoHandler instead)
    suppressWarnings("expressionTypeNothing")
    shared actual LookupElement newParameterInfo(Integer offset, Declaration dec, 
        Reference producedReference, Scope scope, CompletionData data, Boolean namedInvocation) => nothing;

    shared actual LookupElement newFunctionCompletionProposal(Integer offset, String prefix,
        String desc, String text, Declaration dec, Unit unit, CompletionData data) {
        
        return IdeaFunctionCompletionProposal(offset, prefix, desc, text, dec, data).lookupElement;
    }

    shared actual LookupElement newControlStructureCompletionProposal(Integer offset, String prefix,
        String desc, String text, Declaration dec, CompletionData data) {
        value loc = text.firstOccurrence('}') 
            else ((text.firstOccurrence(';') else - 1) + 1);
        value selection = TextRange.from(offset + loc - prefix.size, 0);
        
        return newLookup(desc, text, ideaIcons.correction, null, selection);
    }
    
    shared actual LookupElement newNestedLiteralCompletionProposal(String val, Integer loc, Integer index) {
        print("newNestedLiteralCompletionProposal ``val``");
        return LookupElementBuilder.create(val);
    }
    
    shared actual LookupElement newNestedCompletionProposal(Declaration dec, Declaration? qualifier, Integer loc,
        Integer index, Boolean basic, String op) {
        
        print("newNestedCompletionProposal ``dec.qualifiedNameString``");
        
        return MyLookupElementBuilder(dec, dec.unit, false).lookupElement;
    }
    
    shared actual LookupElement newTypeProposal(Integer offset, Type? type, String text, String desc, Tree.CompilationUnit rootNode) {
        return IdeaTypeProposal(offset, type, text, desc, rootNode).lookupElement;
    }
    
}

class MyLookupElementBuilder(Declaration decl, Unit unit, Boolean allowInvocation, 
        String? typeArgs = null, Declaration? parentDecl = null) {
    
    String text = (if (exists name = parentDecl?.nameAsString) 
                  then "``name``.``decl.nameAsString``"
                  else decl.nameAsString)
                + (typeArgs else "");
    
    variable String tailText = "";
    variable Boolean grayTailText = false;
    variable Icon? icon = null;
    variable String? typeText = null;
    variable InsertHandler<LookupElement>? handler = null;
    
    void visitFunction(Function fun) {
        if (fun.annotation) {
            icon = PlatformIcons.\iANNOTATION_TYPE_ICON;
        } else {
            icon = PlatformIcons.\iMETHOD_ICON;
            
            if (allowInvocation) {
                value params = Iter(fun.firstParameterList.parameters).map((p) => p.type.declaration.name + " " + p.name);
                tailText = "(``", ".join(params)``)";
                typeText = if (fun.declaredVoid) then "void" else fun.typeDeclaration.name;
                handler = functionInsertHandler;
            } else {
                handler = declarationInsertHandler;
            }
        }
    }
    
    void visitValue(Value val) {
        if (is Class t = val.type?.declaration, t.name.first?.lowercase else false) {
            icon = PlatformIcons.\iANONYMOUS_CLASS_ICON;
            handler = declarationInsertHandler;
        } else {
            icon = PlatformIcons.\iPROPERTY_ICON;
            typeText = val.typeDeclaration?.name;
        }
    }
    
    void visitClass(Class klass) {
        icon = PlatformIcons.\iCLASS_ICON;
        tailText = " (``klass.container.qualifiedNameString``)";
        grayTailText = true;
        handler = declarationInsertHandler;
    }
    
    void visitInterface(Interface int) {
        icon = PlatformIcons.\iINTERFACE_ICON;
        tailText = " (``int.container.qualifiedNameString``)";
        grayTailText = true;
        handler = declarationInsertHandler;
    }
    
    void visitAlias(TypeAlias typeAlias) {
        print("alias");
        // TODO create an icon for aliases
    }
    
    void visit(Declaration decl) {
        if (is Function decl) {
            visitFunction(decl);
        } else if (is Value decl) {
            visitValue(decl);
        } else if (is Class decl) {
            visitClass(decl);
        } else if (is Interface decl) {
            visitInterface(decl);
        } else if (is TypeAlias decl) {
            visitAlias(decl);
        }
    }
    
    visit(decl);
    
    shared LookupElement lookupElement = LookupElementBuilder.create([decl, unit], text)
        .withTailText(tailText, grayTailText)
        .withTypeText(typeText)
        .withIcon(icon)
        .withInsertHandler(handler);
}
