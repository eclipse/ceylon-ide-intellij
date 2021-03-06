/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.intellij.correct {
    RefineFormalMembersIntention
}
import com.intellij.lang {
    LanguageCodeInsightActionHandler
}
import com.intellij.openapi.editor {
    Editor
}
import com.intellij.psi {
    PsiFile
}
import com.intellij.openapi.project {
    Project
}
import org.eclipse.ceylon.ide.intellij.psi {
    CeylonFile
}
import com.intellij.openapi.command {
    WriteCommandAction
}
import com.intellij.openapi.application {
    Result
}

shared class RefineFormalMembersAction() extends AbstractIntentionAction() 
        satisfies LanguageCodeInsightActionHandler {
    
    commandName => "Refine formal members";
    
    createIntention() => RefineFormalMembersIntention();
    
    shared actual void invoke(Project project, Editor editor, PsiFile file) {
        value intention = createIntention();
        if (intention.isAvailable(project, editor, file)) {
            value p = project;
            value cn = commandName;
            object extends WriteCommandAction<Nothing>(p, cn, file) {
                run(Result<Nothing> result) 
                        => intention.invoke(project, editor, file);
            }.execute();
        }
    }
    
    isValidFor(Editor editor, PsiFile psiFile) => psiFile is CeylonFile;
    
    startInWriteAction() => false;
    
}
