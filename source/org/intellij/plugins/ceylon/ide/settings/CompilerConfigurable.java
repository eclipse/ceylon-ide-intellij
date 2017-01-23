package org.intellij.plugins.ceylon.ide.settings;

import com.intellij.openapi.options.Configurable;
import com.intellij.openapi.options.ConfigurationException;
import com.intellij.openapi.options.SearchableConfigurable;
import com.intellij.uiDesigner.core.GridConstraints;
import com.intellij.uiDesigner.core.GridLayoutManager;
import com.intellij.uiDesigner.core.Spacer;
import org.intellij.plugins.ceylon.ide.settings.ceylonSettings_;
import org.intellij.plugins.ceylon.ide.settings.CeylonSettings;
import org.jetbrains.annotations.Nls;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;
import javax.swing.event.ChangeEvent;
import javax.swing.event.ChangeListener;
import java.awt.*;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;

public class CompilerConfigurable implements SearchableConfigurable, Configurable.NoScroll {
    private JRadioButton inProcessMode;
    private JRadioButton outProcessMode;
    private JPanel mainPanel;
    private JCheckBox verboseCheckbox;
    private JCheckBox allCheckBox;
    private JCheckBox loaderCheckBox;
    private JCheckBox astCheckBox;
    private JCheckBox codeCheckBox;
    private JCheckBox cmrCheckBox;
    private JCheckBox benchmarkCheckBox;

    private List<JCheckBox> verbosities = Arrays.asList(
            allCheckBox, loaderCheckBox, astCheckBox,
            codeCheckBox, cmrCheckBox, benchmarkCheckBox
    );

    public CompilerConfigurable() {
        verboseCheckbox.addChangeListener(new ChangeListener() {
            @Override
            public void stateChanged(ChangeEvent e) {
                for (JCheckBox cb : verbosities) {
                    cb.setEnabled(verboseCheckbox.isSelected());
                }
            }
        });

        allCheckBox.addChangeListener(new ChangeListener() {
            @Override
            public void stateChanged(ChangeEvent e) {
                for (JCheckBox cb : verbosities) {
                    if (cb != allCheckBox) {
                        cb.setEnabled(!allCheckBox.isSelected());
                    }
                }
            }
        });

        for (JCheckBox cb : verbosities) {
            cb.setEnabled(verboseCheckbox.isSelected());
        }
    }

    @NotNull
    @Override
    public String getId() {
        return "preferences.Ceylon.compiler";
    }

    @Nullable
    @Override
    public Runnable enableSearch(String option) {
        return null;
    }

    @Nls
    @Override
    public String getDisplayName() {
        return "Ceylon compiler";
    }

    @Nullable
    @Override
    public String getHelpTopic() {
        return null;
    }

    @Nullable
    @Override
    public JComponent createComponent() {
        return mainPanel;
    }

    @Override
    public boolean isModified() {
        CeylonSettings settings = ceylonSettings_.get_();

        return outProcessMode.isSelected() != settings.getUseOutProcessBuild()
                || verboseCheckbox.isSelected() != settings.getCompilerVerbose()
                || !Objects.equals(getVerbosityLevel(), settings.getVerbosityLevel());
    }

    @Override
    public void apply() throws ConfigurationException {
        CeylonSettings settings = ceylonSettings_.get_();
        settings.setUseOutProcessBuild(outProcessMode.isSelected());
        settings.setCompilerVerbose(verboseCheckbox.isSelected());
        settings.setVerbosityLevel(getVerbosityLevel());
    }

    @Override
    public void reset() {
        CeylonSettings settings = ceylonSettings_.get_();
        outProcessMode.setSelected(settings.getUseOutProcessBuild());
        inProcessMode.setSelected(!settings.getUseOutProcessBuild());
        verboseCheckbox.setSelected(settings.getCompilerVerbose());
        setVerbosityLevel(settings.getVerbosityLevel());
    }

    @Override
    public void disposeUIResources() {
    }

    private String getVerbosityLevel() {
        if (allCheckBox.isSelected()) {
            return "all";
        } else {
            StringBuilder builder = new StringBuilder();

            for (JCheckBox cb : verbosities) {
                if (cb.isSelected()) {
                    if (builder.length() > 0) {
                        builder.append(",");
                    }
                    builder.append(cb.getText());
                }
            }

            return builder.toString();
        }
    }

    private void setVerbosityLevel(String level) {
        for (JCheckBox cb : verbosities) {
            cb.setSelected(false);
        }

        String[] parts = level.split(",");

        for (String part : parts) {
            for (JCheckBox cb : verbosities) {
                if (Objects.equals(cb.getText(), part)) {
                    cb.setSelected(true);
                }
            }
        }
    }

    {
// GUI initializer generated by IntelliJ IDEA GUI Designer
// >>> IMPORTANT!! <<<
// DO NOT EDIT OR ADD ANY CODE HERE!
        $$$setupUI$$$();
    }

    /**
     * Method generated by IntelliJ IDEA GUI Designer
     * >>> IMPORTANT!! <<<
     * DO NOT edit this method OR call it in your code!
     *
     * @noinspection ALL
     */
    private void $$$setupUI$$$() {
        mainPanel = new JPanel();
        mainPanel.setLayout(new GridLayoutManager(3, 1, new Insets(0, 0, 0, 0), -1, -1));
        final JPanel panel1 = new JPanel();
        panel1.setLayout(new GridLayoutManager(2, 1, new Insets(0, 0, 0, 0), -1, -1));
        mainPanel.add(panel1, new GridConstraints(0, 0, 1, 1, GridConstraints.ANCHOR_CENTER, GridConstraints.FILL_BOTH, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, null, null, null, 0, false));
        panel1.setBorder(BorderFactory.createTitledBorder("Compiler execution mode"));
        inProcessMode = new JRadioButton();
        inProcessMode.setEnabled(false);
        inProcessMode.setText("In-process (uses incremental typechecking)");
        panel1.add(inProcessMode, new GridConstraints(1, 0, 1, 1, GridConstraints.ANCHOR_WEST, GridConstraints.FILL_NONE, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, GridConstraints.SIZEPOLICY_FIXED, null, new Dimension(447, 26), null, 0, false));
        outProcessMode = new JRadioButton();
        outProcessMode.setSelected(true);
        outProcessMode.setText("Out-of-process (uses 'ceylon compile')");
        panel1.add(outProcessMode, new GridConstraints(0, 0, 1, 1, GridConstraints.ANCHOR_WEST, GridConstraints.FILL_NONE, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, GridConstraints.SIZEPOLICY_FIXED, null, new Dimension(447, 26), null, 0, false));
        final Spacer spacer1 = new Spacer();
        mainPanel.add(spacer1, new GridConstraints(2, 0, 1, 1, GridConstraints.ANCHOR_CENTER, GridConstraints.FILL_VERTICAL, 1, GridConstraints.SIZEPOLICY_WANT_GROW, null, null, null, 0, false));
        final JPanel panel2 = new JPanel();
        panel2.setLayout(new GridLayoutManager(3, 4, new Insets(0, 0, 0, 0), -1, -1));
        mainPanel.add(panel2, new GridConstraints(1, 0, 1, 1, GridConstraints.ANCHOR_CENTER, GridConstraints.FILL_BOTH, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, null, null, null, 0, false));
        panel2.setBorder(BorderFactory.createTitledBorder("Compiler verbosity"));
        verboseCheckbox = new JCheckBox();
        verboseCheckbox.setText("Display verbose compiler output");
        panel2.add(verboseCheckbox, new GridConstraints(0, 0, 1, 4, GridConstraints.ANCHOR_WEST, GridConstraints.FILL_NONE, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, GridConstraints.SIZEPOLICY_FIXED, null, null, null, 0, false));
        allCheckBox = new JCheckBox();
        allCheckBox.setText("all");
        panel2.add(allCheckBox, new GridConstraints(1, 0, 1, 1, GridConstraints.ANCHOR_WEST, GridConstraints.FILL_NONE, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, GridConstraints.SIZEPOLICY_FIXED, null, null, null, 2, false));
        final Spacer spacer2 = new Spacer();
        panel2.add(spacer2, new GridConstraints(1, 3, 1, 1, GridConstraints.ANCHOR_CENTER, GridConstraints.FILL_HORIZONTAL, GridConstraints.SIZEPOLICY_WANT_GROW, 1, null, null, null, 0, false));
        codeCheckBox = new JCheckBox();
        codeCheckBox.setText("code");
        panel2.add(codeCheckBox, new GridConstraints(1, 1, 1, 1, GridConstraints.ANCHOR_WEST, GridConstraints.FILL_NONE, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, GridConstraints.SIZEPOLICY_FIXED, null, null, null, 0, false));
        astCheckBox = new JCheckBox();
        astCheckBox.setText("ast");
        panel2.add(astCheckBox, new GridConstraints(1, 2, 1, 1, GridConstraints.ANCHOR_WEST, GridConstraints.FILL_NONE, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, GridConstraints.SIZEPOLICY_FIXED, null, null, null, 0, false));
        cmrCheckBox = new JCheckBox();
        cmrCheckBox.setText("cmr");
        panel2.add(cmrCheckBox, new GridConstraints(2, 1, 1, 1, GridConstraints.ANCHOR_WEST, GridConstraints.FILL_NONE, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, GridConstraints.SIZEPOLICY_FIXED, null, null, null, 0, false));
        benchmarkCheckBox = new JCheckBox();
        benchmarkCheckBox.setText("benchmark");
        panel2.add(benchmarkCheckBox, new GridConstraints(2, 2, 1, 1, GridConstraints.ANCHOR_WEST, GridConstraints.FILL_NONE, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, GridConstraints.SIZEPOLICY_FIXED, null, null, null, 0, false));
        loaderCheckBox = new JCheckBox();
        loaderCheckBox.setText("loader");
        panel2.add(loaderCheckBox, new GridConstraints(2, 0, 1, 1, GridConstraints.ANCHOR_WEST, GridConstraints.FILL_NONE, GridConstraints.SIZEPOLICY_CAN_SHRINK | GridConstraints.SIZEPOLICY_CAN_GROW, GridConstraints.SIZEPOLICY_FIXED, null, null, null, 2, false));
        ButtonGroup buttonGroup;
        buttonGroup = new ButtonGroup();
        buttonGroup.add(inProcessMode);
        buttonGroup.add(outProcessMode);
    }

    /**
     * @noinspection ALL
     */
    public JComponent $$$getRootComponent$$$() {
        return mainPanel;
    }
}
