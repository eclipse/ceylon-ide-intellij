/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import com.intellij.psi {
    PsiParameter
}
import org.eclipse.ceylon.model.loader.mirror {
    VariableMirror
}
import org.eclipse.ceylon.ide.intellij.model {
    concurrencyManager {
        needReadAccess
    }
}

class PSIParameter(PsiParameter psiParameter)
        extends PSIAnnotatedMirror(pointer(psiParameter))
        satisfies VariableMirror {

    shared actual late PSIType type
            = needReadAccess(() => PSIType(psiParameter.type));

    string => "PSIVariable[``name``]";
}

