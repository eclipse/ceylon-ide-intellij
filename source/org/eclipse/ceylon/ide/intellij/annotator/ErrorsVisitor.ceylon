/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.collection {
    LinkedList
}

import com.intellij.openapi.util {
    TextRange
}
import org.eclipse.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper,
    Warning
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Message,
    Node,
    UnexpectedError
}
import org.eclipse.ceylon.compiler.typechecker.util {
    WarningSuppressionVisitor
}
import org.eclipse.ceylon.ide.common.util {
    ErrorVisitor
}

import org.eclipse.ceylon.ide.intellij.model {
    findProjectForFile
}
import org.eclipse.ceylon.ide.intellij.psi {
    CeylonFile
}


"A visitor that visits a compilation unit returned by
 [[org.eclipse.ceylon.compiler.typechecker.parser::CeylonParser]] to gather errors and
  warnings."
shared class ErrorsVisitor(Tree.CompilationUnit compilationUnit, CeylonFile file) extends ErrorVisitor() {

    value messages = LinkedList<[Message, TextRange?]>();

    handleException(Exception e, Node that) => e.printStackTrace();
    
    shared {[Message, TextRange?]*} extractMessages() {
        if (exists ceylonProject = findProjectForFile(file)) {
            compilationUnit.visit(WarningSuppressionVisitor(`Warning`,
                ceylonProject.configuration.suppressWarningsEnum));
        }
        compilationUnit.visit(this);

        if (file.name == "module.ceylon",
            exists project = findProjectForFile(file)) {

            value errors = project.build
                .messagesForSourceFile(file.virtualFile)
                .map((msg) => msg.typecheckerMessage)
                .narrow<ModuleSourceMapper.ModuleDependencyAnalysisError>();

            messages.addAll(errors.map((err) {
                value range = TextRange(
                    err.treeNode.startIndex.intValue(),
                    err.treeNode.endIndex.intValue()
                );
                return [err, range];
            }));
        }

        return messages;
    }

    shared actual void handleMessage(Integer startOffset, Integer endOffset,
        Integer startCol, Integer startLine, Message error) {
        if (error is UnexpectedError) {
            process.writeError(error.message);
        }
        else {
            messages.add([error, TextRange(startOffset, endOffset)]);
        }
    }

}
